//! Explicit disk downloads of original NZB files, independent of archive parsing.
use super::streaming::{ProviderConfigDto, RUNTIME};
use crate::engine::{nntp::TlsNntpConnector, nntp_source::NntpByteSource, nzb};
use once_cell::sync::Lazy;
use std::{
    collections::HashSet,
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, Mutex,
    },
    time::{SystemTime, UNIX_EPOCH},
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    sync::watch,
};

const MAX_BYTES: u64 = 200 * 1024 * 1024 * 1024;
const CHUNK: u64 = 1024 * 1024;

#[derive(Clone)]
pub struct DownloadProgressDto {
    pub session_id: u64,
    /// loading / downloading / complete / cancelled / failed
    pub phase: String,
    pub completed_bytes: u64,
    /// Decoded bytes discovered so far; not an encoded NZB size estimate.
    pub discovered_bytes: u64,
    pub completed_files: u32,
    pub total_files: u32,
    pub directory: String,
    pub files: Vec<String>,
    pub error: String,
}
struct Download {
    cancel: watch::Sender<bool>,
    progress: Arc<Mutex<DownloadProgressDto>>,
}
static ACTIVE: Lazy<Mutex<Option<Download>>> = Lazy::new(|| Mutex::new(None));
static NEXT: AtomicU64 = AtomicU64::new(1);

fn terminal(phase: &str) -> bool {
    matches!(phase, "complete" | "cancelled" | "failed")
}

fn safe_name(name: &str) -> bool {
    let stem = name.split('.').next().unwrap_or("").to_ascii_uppercase();
    !name.is_empty()
        && name.len() <= 200
        && !name.ends_with([' ', '.'])
        && !name
            .chars()
            .any(|c| c.is_control() || "\\/:*?\"<>|".contains(c))
        && ![
            "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7",
            "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
        ]
        .contains(&stem.as_str())
        && name != "."
        && name != ".."
}

pub fn begin_download(
    config: ProviderConfigDto,
    nzb_path: String,
    destination: String,
) -> Result<u64, String> {
    let _access = crate::edition::lock_media_access()?;
    let root = std::fs::canonicalize(&destination)
        .map_err(|_| "Choose an existing download folder".to_string())?;
    if !root.is_dir() {
        return Err("Choose an existing download folder".into());
    }
    let mut active = ACTIVE.lock().map_err(|_| "Download state unavailable")?;
    if active
        .as_ref()
        .is_some_and(|a| !terminal(&a.progress.lock().expect("download progress").phase))
    {
        return Err("Another download is active. Cancel it first.".into());
    }
    let id = NEXT.fetch_add(1, Ordering::Relaxed);
    let (cancel, receiver) = watch::channel(false);
    let progress = Arc::new(Mutex::new(DownloadProgressDto {
        session_id: id,
        phase: "loading".into(),
        completed_bytes: 0,
        discovered_bytes: 0,
        completed_files: 0,
        total_files: 0,
        directory: String::new(),
        files: vec![],
        error: String::new(),
    }));
    *active = Some(Download {
        cancel,
        progress: progress.clone(),
    });
    RUNTIME.spawn(async move {
        let mut partial: Option<PathBuf> = None;
        let result = run_download(
            config,
            &nzb_path,
            root,
            id,
            receiver.clone(),
            &progress,
            &mut partial,
        )
        .await;
        if let Some(path) = partial {
            let _ = tokio::fs::remove_file(path).await;
        }
        let mut state = progress.lock().expect("download progress");
        match result {
            Ok(()) => state.phase = "complete".into(),
            Err(_) if *receiver.borrow() => state.phase = "cancelled".into(),
            Err(message) => {
                state.phase = "failed".into();
                state.error = message;
            }
        }
    });
    Ok(id)
}

pub fn download_progress(session_id: u64) -> Option<DownloadProgressDto> {
    let active = ACTIVE.lock().ok()?;
    let state = active.as_ref()?.progress.lock().ok()?;
    (state.session_id == session_id).then(|| state.clone())
}

pub fn cancel_download(session_id: u64) {
    if let Ok(active) = ACTIVE.lock() {
        if let Some(active) = active
            .as_ref()
            .filter(|a| a.progress.lock().is_ok_and(|p| p.session_id == session_id))
        {
            let _ = active.cancel.send(true);
        }
    }
}

async fn run_download(
    config: ProviderConfigDto,
    path: &str,
    root: PathBuf,
    id: u64,
    mut cancel: watch::Receiver<bool>,
    progress: &Arc<Mutex<DownloadProgressDto>>,
    partial: &mut Option<PathBuf>,
) -> Result<(), String> {
    let metadata = tokio::fs::metadata(path)
        .await
        .map_err(|_| "NZB could not be opened")?;
    if !metadata.is_file() || metadata.len() > 64 * 1024 * 1024 {
        return Err("NZB is not a supported size".into());
    }
    let mut raw = Vec::new();
    tokio::fs::File::open(path)
        .await
        .map_err(|_| "NZB could not be opened")?
        .take(64 * 1024 * 1024 + 1)
        .read_to_end(&mut raw)
        .await
        .map_err(|_| "NZB could not be read")?;
    if raw.len() > 64 * 1024 * 1024 {
        return Err("NZB is too large".into());
    }
    let parsed = nzb::parse_nzb(std::str::from_utf8(&raw).map_err(|_| "Invalid NZB text")?)
        .map_err(|_| "Invalid NZB")?;
    validate_files(&parsed.files)?;
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| "Clock unavailable")?
        .as_millis();
    if *cancel.borrow() { return Err("Download cancelled".into()); }
    let directory = root.join(format!("zanzibarr-{stamp}-{id}"));
    tokio::fs::create_dir(&directory)
        .await
        .map_err(|_| "Download folder could not be created")?;
    {
        let mut state = progress.lock().expect("download progress");
        state.directory = directory.to_string_lossy().into_owned();
        state.total_files = parsed.files.len() as u32;
        state.phase = "downloading".into();
    }
    let pool = TlsNntpConnector::new(config.into()).into_pool();
    for file in &parsed.files {
        if *cancel.borrow() {
            return Err("Download cancelled".into());
        }
        let name = file.filename().expect("validated filename");
        let source_cancel = cancel.clone();
        let source = tokio::select! {
            biased;
            _ = cancel.changed() => return Err("Download cancelled".into()),
            source = NntpByteSource::with_options(pool.clone(), file, 4, 2, Some(source_cancel)) => source.map_err(|_| "File unavailable from provider; retry or repair the release")?,
        };
        let length = source.file_size().ok_or("Decoded file size unavailable")?;
        {
            let mut state = progress.lock().expect("download progress");
            state.discovered_bytes = state
                .discovered_bytes
                .checked_add(length)
                .filter(|n| *n <= MAX_BYTES)
                .ok_or("Download exceeds the 200 GiB limit")?;
        }
        let staging = directory.join(format!("{name}.zanzibarr-part"));
        let mut output = tokio::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&staging)
            .await
            .map_err(|_| "Could not create download file")?;
        *partial = Some(staging.clone());
        copy_decoded(
            |range| source.read_range_bytes(range),
            length,
            &mut output,
            &mut cancel,
            progress,
        )
        .await?;
        output
            .sync_all()
            .await
            .map_err(|_| "Download could not be saved")?;
        drop(output);
        let finished = directory.join(name);
        tokio::fs::rename(&staging, &finished)
            .await
            .map_err(|_| "Completed download could not be saved")?;
        *partial = None;
        let mut state = progress.lock().expect("download progress");
        state.completed_files += 1;
        state.files.push(finished.to_string_lossy().into_owned());
    }
    Ok(())
}

async fn copy_decoded<F, Fut, W>(
    mut read: F,
    length: u64,
    output: &mut W,
    cancel: &mut watch::Receiver<bool>,
    progress: &Arc<Mutex<DownloadProgressDto>>,
) -> Result<(), String>
where
    F: FnMut(std::ops::Range<u64>) -> Fut,
    Fut: std::future::Future<Output = std::io::Result<Vec<u8>>>,
    W: tokio::io::AsyncWrite + Unpin,
{
    let mut offset = 0;
    while offset < length {
        if *cancel.borrow() {
            return Err("Download cancelled".into());
        }
        let end = (offset + CHUNK).min(length);
        tokio::select! {
            biased;
            _ = cancel.changed() => return Err("Download cancelled".into()),
            result = async {
                let bytes = read(offset..end).await.map_err(|_| "Download interrupted or incomplete")?;
                if bytes.len() as u64 != end - offset { return Err("Decoded file ended early"); }
                output.write_all(&bytes).await.map_err(|_| "Download could not be written; check free space")
            } => result?,
        }
        progress.lock().expect("download progress").completed_bytes += end - offset;
        offset = end;
    }
    Ok(())
}

fn validate_files(files: &[nzb::NzbFile]) -> Result<(), String> {
    if files.is_empty() || files.len() > 4096 {
        return Err("NZB must contain 1 to 4096 files".into());
    }
    let mut names = HashSet::new();
    for file in files {
        let name = file.filename().ok_or("A file has no usable name")?;
        if !safe_name(name) || !names.insert(name.to_lowercase()) {
            return Err("NZB contains an unsafe or duplicate filename".into());
        }
        if file.segments.is_empty() {
            return Err("A file has no segments".into());
        }
    }
    Ok(())
}

// Revoke live work as part of the native edition lock, even if Dart is disposed.
pub(crate) fn cancel_edition_operations() {
    if let Ok(active) = ACTIVE.lock() {
        if let Some(active) = active.as_ref() { let _ = active.cancel.send(true); }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn names_cannot_escape_or_alias_windows_paths() {
        for name in [
            "../movie.mkv",
            "C:movie.mkv",
            "x\\y",
            "NUL.mkv",
            "aux",
            "movie.",
            "movie ",
            "x\n.mkv",
            "..",
        ] {
            assert!(!safe_name(name), "{name}");
        }
        for name in ["movie.mkv", "movie.part01.rar", "movie.r00", "movie.7z.001"] {
            assert!(safe_name(name));
        }
    }
    #[test]
    fn empty_downloads_and_unknown_sessions_are_rejected() {
        assert!(validate_files(&[]).is_err());
        assert!(download_progress(u64::MAX).is_none());
        cancel_download(u64::MAX);
    }
    fn progress() -> Arc<Mutex<DownloadProgressDto>> {
        Arc::new(Mutex::new(DownloadProgressDto {
            session_id: 1,
            phase: "downloading".into(),
            completed_bytes: 0,
            discovered_bytes: 0,
            completed_files: 0,
            total_files: 1,
            directory: String::new(),
            files: vec![],
            error: String::new(),
        }))
    }
    #[tokio::test]
    async fn download_copy_is_bounded_and_rejects_short_decoded_ranges() {
        let state = progress();
        let (_tx, mut cancel) = watch::channel(false);
        let mut output = Vec::new();
        let length = CHUNK + 17;
        copy_decoded(
            |range| async move {
                assert!(range.end - range.start <= CHUNK);
                Ok(vec![42; (range.end - range.start) as usize])
            },
            length,
            &mut output,
            &mut cancel,
            &state,
        )
        .await
        .unwrap();
        assert_eq!(output.len() as u64, length);
        assert_eq!(state.lock().unwrap().completed_bytes, length);
        assert!(copy_decoded(
            |_| async { Ok(vec![]) },
            10,
            &mut output,
            &mut cancel,
            &state
        )
        .await
        .is_err());
    }
    #[tokio::test]
    async fn cancellation_stops_copy_before_fetching_more_data() {
        let state = progress();
        let (tx, mut cancel) = watch::channel(false);
        tx.send(true).unwrap();
        let mut output = Vec::new();
        let result = copy_decoded(
            |_| async {
                panic!("must not fetch after cancellation");
                #[allow(unreachable_code)]
                Ok(vec![])
            },
            10,
            &mut output,
            &mut cancel,
            &state,
        )
        .await;
        assert!(result.is_err());
        assert!(output.is_empty());
    }
}
