// Replaced only in isolated edition candidates by tools/prepare_edition.py.
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Mutex, MutexGuard,
};

pub(crate) const NAME: &str = "legacy";
pub(crate) const POLICY: &str = "clean-v1";
static UNLOCKED: AtomicBool = AtomicBool::new(false);
static GENERATION: AtomicU64 = AtomicU64::new(0);
static ACCESS: Mutex<()> = Mutex::new(());

pub(crate) fn require_media_access() -> Result<(), String> {
    if NAME == "legacy" || (NAME == "restricted" && UNLOCKED.load(Ordering::SeqCst)) {
        Ok(())
    } else {
        Err("edition media admission is unavailable".to_owned())
    }
}

pub(crate) fn lock_media_access() -> Result<MutexGuard<'static, ()>, String> {
    let lock = ACCESS
        .lock()
        .map_err(|_| "edition access unavailable".to_owned())?;
    require_media_access()?;
    Ok(lock)
}

pub(crate) fn generation() -> u64 {
    GENERATION.load(Ordering::SeqCst)
}

/// Called by the Windows runner only after OS authentication, and on every
/// cancellation/relock. No persisted permission or cross-process token exists.
#[no_mangle]
pub extern "C" fn zanzibarr_set_restricted_access(granted: u8) -> bool {
    if NAME != "restricted" {
        return false;
    }
    let Ok(_access) = ACCESS.lock() else {
        return false;
    };
    GENERATION.fetch_add(1, Ordering::SeqCst);
    UNLOCKED.store(granted == 1, Ordering::SeqCst);
    if granted != 1 {
        crate::api::streaming::cancel_edition_operations();
        crate::api::repair::cancel_edition_operations();
        crate::api::download::cancel_edition_operations();
    }
    true
}

/// Stable, data-only exports for auditing a built DLL without initializing FRB.
#[no_mangle]
pub extern "C" fn zanzibarr_edition_code() -> u32 {
    match NAME {
        "legacy" => 0,
        "clean" => 1,
        "restricted" => 2,
        _ => 255,
    }
}
#[no_mangle]
pub extern "C" fn zanzibarr_policy_version() -> u32 {
    u32::from(POLICY == "clean-v1")
}

pub(crate) fn temporary_root() -> std::path::PathBuf {
    temporary_root_for(NAME)
}
fn temporary_root_for(edition: &str) -> std::path::PathBuf {
    let root = std::env::temp_dir();
    if edition == "legacy" {
        root
    } else {
        root.join("zanzibarr-editions").join(edition)
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn editions_start_closed_except_legacy() {
        assert_eq!(
            super::require_media_access().is_ok(),
            super::NAME == "legacy"
        );
    }
    #[test]
    fn native_temporary_roots_do_not_cross_editions() {
        assert_eq!(super::temporary_root_for("legacy"), std::env::temp_dir());
        assert_ne!(
            super::temporary_root_for("clean"),
            super::temporary_root_for("restricted")
        );
        assert_ne!(
            super::temporary_root_for("legacy"),
            super::temporary_root_for("restricted")
        );
    }
    #[test]
    fn unadmitted_public_entrypoints_do_not_touch_media_or_network() {
        if super::NAME == "legacy" {
            return;
        }
        use crate::api::{download, repair, search, streaming};
        let indexer = || search::IndexerConfigDto {
            structured: None,
            id: None,
            base_url: "not-a-url".into(),
            api_key: "TESTPASS123".into(),
            nickname: "private".into(),
        };
        let provider = || streaming::ProviderConfigDto {
            host: "not-a-host".into(),
            port: 563,
            username: "test".into(),
            password: "TESTPASS123".into(),
            max_connections: 1,
        };
        assert!(search::newznab_check_caps(indexer()).is_err());
        assert!(search::newznab_search(indexer(), "private".into(), 10, 0).is_err());
        let many = search::newznab_search_many(vec![indexer()], "private".into(), 10, 0, None);
        assert!(many.page.items.is_empty());
        assert_eq!(many.has_more, Some(false));
        assert!(search::newznab_download_nzb(
            indexer(),
            "not-a-url".into(),
            "private".into(),
            None
        )
        .is_err());
        assert!(streaming::check_provider(provider()).is_err());
        assert!(streaming::start_stream(provider(), "missing.nzb".into()).is_err());
        assert_eq!(
            streaming::begin_stream(provider(), "missing.nzb".into(), None),
            0
        );
        assert_eq!(
            repair::begin_repair(provider(), "missing.nzb".into(), None),
            0
        );
        assert!(download::begin_download(
            provider(),
            "missing.nzb".into(),
            "missing-folder".into()
        )
        .is_err());
        assert!(streaming::RUNTIME
            .block_on(streaming::list_playable_entries("missing.nzb".into()))
            .is_err());
    }
    #[test]
    fn restricted_native_grants_are_ephemeral_and_clean_cannot_unlock() {
        if super::NAME == "restricted" {
            assert!(super::zanzibarr_set_restricted_access(1));
            assert!(super::require_media_access().is_ok());
            assert!(super::zanzibarr_set_restricted_access(0));
            assert!(super::require_media_access().is_err());
        } else {
            assert!(!super::zanzibarr_set_restricted_access(1));
        }
    }
}
