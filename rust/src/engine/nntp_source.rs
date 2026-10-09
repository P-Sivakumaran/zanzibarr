//! [`RangeSource`] için gerçek uygulama: NZB dosyasını, NNTP havuzu ve
//! segment↔byte-range eşleyicisi üzerinden bir byte akışı gibi sunar.
//!
//! Akış: bir byte aralığı istenince [`SegmentLocator`] o aralığı kapsayan
//! segmentleri belirler; kaydı olmayanlar havuzdan çekilip yEnc çözülür,
//! konumları kaydedilir; sonra dilimler sırayla çıktı akışına yazılır.
//!
//! Çözülmüş veriler sınırlı bir FIFO önbellekte tutulur (seek sırasında
//! komşu isteklerin tekrar çekmesini önler); önbellekten düşen segment
//! yeniden istenirse tekrar çekilir. Bellek, GB'lık dosyalarda bile
//! önbellek kapasitesiyle sınırlı kalır.

use std::collections::{HashMap, HashSet, VecDeque};
use std::future::Future;
use std::io;
use std::ops::Range;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tokio::io::{AsyncWrite, AsyncWriteExt};
use tokio::sync::{watch, Notify};
use tokio::task::JoinSet;

use super::archive::wait_for_cancellation;
use super::locator::{LocatorError, SegmentLocator};
use super::nntp::{NntpError, NntpPool, TlsNntpConnector};
use super::nzb::NzbFile;
use super::server::{content_type_for, RangeSource};
use super::yenc;

pub(crate) const BODY_READ_TIMEOUT: Duration = Duration::from_secs(30);

/// Önden çekim dalgasının genişliği (segment sayısı). Sıralı okuyucu bir
/// segmenti beklerken sonraki segmentler yedek havuz bağlantılarıyla paralel
/// çekilir; tek-segmentlik gidiş-dönüş gecikmesi akış hızını sınırlamaz.
pub(crate) const DEFAULT_PREFETCH_DEPTH: usize = 8;

/// Arşiv ciltleri için daha dar dalga: her cildin kendi kaynağı vardır ve
/// cilt sayısı çok olduğundan bellek baskısı cilt başına büyür.
pub(crate) const ARCHIVE_PREFETCH_DEPTH: usize = 4;

/// Başka görevin çekmekte olduğu segmenti beklerken uyanma aralığı. Gerçek
/// uyanma `Notify` ile anında gelir; bu yalnız kaçan sinyale karşı emniyettir.
const INFLIGHT_WAIT_POLL: Duration = Duration::from_millis(100);

pub(crate) async fn read_body_with_timeout(
    duration: Duration,
    future: impl Future<Output = Result<Vec<u8>, NntpError>>,
) -> Result<Vec<u8>, NntpError> {
    tokio::time::timeout(duration, future)
        .await
        .map_err(|_| NntpError::Timeout {
            operation: "NNTP BODY",
        })?
}

/// Çözülmüş segment verisi için basit kapasiteli FIFO önbellek.
pub(crate) struct SegmentCache {
    capacity: usize,
    map: HashMap<usize, Arc<Vec<u8>>>,
    order: VecDeque<usize>,
}

impl SegmentCache {
    pub(crate) fn new(capacity: usize) -> Self {
        SegmentCache {
            capacity: capacity.max(1),
            map: HashMap::new(),
            order: VecDeque::new(),
        }
    }

    pub(crate) fn get(&self, index: usize) -> Option<Arc<Vec<u8>>> {
        self.map.get(&index).cloned()
    }

    pub(crate) fn insert(&mut self, index: usize, data: Arc<Vec<u8>>) {
        if self.map.contains_key(&index) {
            return;
        }
        while self.order.len() >= self.capacity {
            if let Some(evicted) = self.order.pop_front() {
                self.map.remove(&evicted);
            } else {
                break;
            }
        }
        self.order.push_back(index);
        self.map.insert(index, data);
    }
}

/// Bir kaynağın segment çekim durumu: havuz, eşleyici, önbellek ve önden
/// çekim dalgası denetimi. `Arc` içinde paylaşılır; prefetch görevleri bu
/// bağlamın bir klonuyla (referans sayaçlı) yaşar, kaynak düşse bile görev
/// gövdesi geçerli kalır — oturum iptali watch kanalından duyurulur.
struct FetchContext {
    pool: Arc<NntpPool<TlsNntpConnector>>,
    locator: Mutex<SegmentLocator>,
    cache: Mutex<SegmentCache>,
    /// Halen bir görev tarafından çekilmekte olan segmentler. Aynı segmentin
    /// eşzamanlı iki kez indirilmesini engeller.
    inflight: Mutex<HashSet<usize>>,
    inflight_notify: Notify,
    prefetch_depth: usize,
    cancellation: Option<watch::Receiver<bool>>,
}

/// Request-owned tasks. Completed fetches never advance the window: only
/// consumption does. Dropping a read future also aborts its pending prefetches.
struct PrefetchWindow {
    tasks: JoinSet<()>,
    next: Option<usize>,
    depth: usize,
}

impl PrefetchWindow {
    fn new(depth: usize) -> Self {
        Self {
            tasks: JoinSet::new(),
            next: None,
            depth,
        }
    }

    fn advance<F, Fut>(&mut self, index: usize, count: usize, mut fetch: F)
    where
        F: FnMut(usize) -> Fut,
        Fut: Future<Output = ()> + Send + 'static,
    {
        while self.tasks.try_join_next().is_some() {}
        let start = index.saturating_add(1);
        let end = start.saturating_add(self.depth).min(count);
        for next in self.next.unwrap_or(start).max(start)..end {
            self.tasks.spawn(fetch(next));
        }
        self.next = Some(end);
    }
}

/// Release the claim on success, error, or cancellation of a fetch future.
struct InflightFetch {
    ctx: Arc<FetchContext>,
    index: usize,
}

impl Drop for InflightFetch {
    fn drop(&mut self) {
        self.ctx.inflight.lock().expect("kilit").remove(&self.index);
        self.ctx.inflight_notify.notify_waiters();
    }
}

impl FetchContext {
    /// Segmenti önbellekten döndürür; yoksa çeker. Aynı segmenti başka görev
    /// çekiyorsa onun bitmesini bekler ve önbelleğe düşen veriyi paylaşır.
    /// Prefetch is scheduled separately by the consuming request.
    async fn fetch_and_cache(self: &Arc<Self>, index: usize) -> io::Result<Arc<Vec<u8>>> {
        loop {
            if let Some(data) = self.cache.lock().expect("kilit").get(index) {
                return Ok(data);
            }
            {
                let mut inflight = self.inflight.lock().expect("kilit");
                if inflight.insert(index) {
                    break; // çekim hakkı bizde
                }
            }
            // Başka görev çekiyor: bitince önbellekten alınır.
            let _ = tokio::time::timeout(INFLIGHT_WAIT_POLL, self.inflight_notify.notified()).await;
        }

        let _claim = InflightFetch {
            ctx: Arc::clone(self),
            index,
        };
        self.fetch(index).await
    }

    /// Segmenti havuzdan çeker, yEnc çözer, konumunu eşleyiciye kaydeder ve
    /// önbelleğe koyar. Çağıranın inflight hakkını önceden aldığı varsayılır.
    async fn fetch(&self, index: usize) -> io::Result<Arc<Vec<u8>>> {
        let message_id = {
            let loc = self.locator.lock().expect("kilit");
            loc.message_id(index)
                .ok_or_else(|| io::Error::other(format!("segment {index} yok")))?
                .to_string()
        };

        let work = async {
            let mut conn = self
                .pool
                .checkout()
                .await
                .map_err(|e| io::Error::other(e.to_string()))?;
            let body_result =
                read_body_with_timeout(BODY_READ_TIMEOUT, conn.body_by_message_id(&message_id))
                    .await;
            let body = match body_result {
                Ok(body) => {
                    // Durum satırı ve multiline sonlandırıcısı eksiksiz okundu.
                    // Bu noktadan önce future iptal edilirse varsayılan Drop
                    // davranışı yarım soketi kapatır.
                    conn.mark_reusable();
                    body
                }
                Err(err) => return Err(io::Error::other(err.to_string())),
            };
            drop(conn); // bağlantı havuza döner

            yenc::decode(&body).map_err(|e| io::Error::other(e.to_string()))
        };

        let part = match &self.cancellation {
            Some(cancellation) => {
                let mut cancellation = cancellation.clone();
                tokio::select! {
                    biased;
                    _ = wait_for_cancellation(&mut cancellation) => {
                        return Err(io::Error::new(
                            io::ErrorKind::Interrupted,
                            "segment fetch cancelled",
                        ));
                    }
                    result = work => result?,
                }
            }
            None => work.await?,
        };

        let data = Arc::new(part.data.clone());
        {
            let mut loc = self.locator.lock().expect("kilit");
            if !loc.is_located(index) {
                loc.record_part(index, &part)
                    .map_err(|e| io::Error::other(e.to_string()))?;
            }
        }
        self.cache
            .lock()
            .expect("kilit")
            .insert(index, Arc::clone(&data));
        Ok(data)
    }
}

pub struct NntpByteSource {
    ctx: Arc<FetchContext>,
    content_type: &'static str,
    filename: String,
    /// PAR2 onarımı sonrası hasarlı bölgeleri karşılayan yerel katman.
    overlay: Mutex<Option<Arc<crate::engine::repair::FileOverlay>>>,
}

impl NntpByteSource {
    /// Varsayılan önbellek kapasitesi (segment sayısı) — ~1 MB'lık parçalarla
    /// birkaç yüz MB'lık kayan pencere.
    pub const DEFAULT_CACHE_SEGMENTS: usize = 256;

    /// Kaynağı kurar ve ilk segmenti çekerek dosya boyutunu (yEnc `size`)
    /// öğrenir; böylece [`RangeSource::total_len`] server başlar başlamaz
    /// hazırdır.
    pub async fn new(pool: Arc<NntpPool<TlsNntpConnector>>, file: &NzbFile) -> io::Result<Self> {
        Self::with_options(
            pool,
            file,
            Self::DEFAULT_CACHE_SEGMENTS,
            DEFAULT_PREFETCH_DEPTH,
            None,
        )
        .await
    }

    pub async fn with_cache_capacity(
        pool: Arc<NntpPool<TlsNntpConnector>>,
        file: &NzbFile,
        cache_segments: usize,
    ) -> io::Result<Self> {
        Self::with_options(pool, file, cache_segments, ARCHIVE_PREFETCH_DEPTH, None).await
    }

    /// Tam yapılandırma: önbellek kapasitesi, önden çekim dalgası derinliği
    /// (0 = kapalı) ve isteğe bağlı oturum iptali. İptal verilirse yarım kalan
    /// prefetch/çekim görevleri oturum kapanırken durdurulur.
    pub async fn with_options(
        pool: Arc<NntpPool<TlsNntpConnector>>,
        file: &NzbFile,
        cache_segments: usize,
        prefetch_depth: usize,
        cancellation: Option<watch::Receiver<bool>>,
    ) -> io::Result<Self> {
        let filename = file.filename().unwrap_or("stream.bin").to_string();
        let content_type = content_type_for(&filename);
        let source = NntpByteSource {
            ctx: Arc::new(FetchContext {
                pool,
                locator: Mutex::new(SegmentLocator::from_nzb_file(file)),
                cache: Mutex::new(SegmentCache::new(cache_segments)),
                inflight: Mutex::new(HashSet::new()),
                inflight_notify: Notify::new(),
                prefetch_depth: prefetch_depth.min(cache_segments.saturating_sub(1)),
                cancellation,
            }),
            content_type,
            filename,
            overlay: Mutex::new(None),
        };
        // Bootstrap: ilk segment → file_size + tek tip parça boyutu. Bu
        // yerleşim öğrenimidir; önden çekim dalgası kurulmaz (okunmayacak
        // segmentler boşuna inmez).
        {
            let ctx = Arc::clone(&source.ctx);
            ctx.fetch_and_cache(0).await?;
        }
        if source.file_size().is_none() {
            return Err(io::Error::other("could not learn file size from the first segment"));
        }
        Ok(source)
    }

    pub fn file_size(&self) -> Option<u64> {
        self.ctx.locator.lock().expect("kilit").file_size()
    }

    pub fn segment_count(&self) -> usize {
        self.ctx.locator.lock().expect("kilit").segment_count()
    }

    pub fn filename(&self) -> &str {
        &self.filename
    }

    /// Segmentin konumu eşleyicide kayıtlı olana dek çeker.
    async fn ensure_located(&self, index: usize) -> io::Result<()> {
        if self.ctx.locator.lock().expect("kilit").is_located(index) {
            return Ok(());
        }
        self.ctx.fetch_and_cache(index).await?;
        Ok(())
    }

    /// Segmentin çözülmüş verisini önbellekten alır; yoksa yeniden çeker.
    async fn segment_data(&self, index: usize) -> io::Result<Arc<Vec<u8>>> {
        self.ctx.fetch_and_cache(index).await
    }

    /// `offset`'i içeren segmentin indeksini ve çözülmüş dosya aralığını,
    /// gerekiyorsa o segmenti çekerek bulur. Yalnızca bu tek segment için
    /// veri getirir — böylece açık uçlu (`bytes=0-`) isteklerde tüm dosya
    /// önden çekilmez; player okudukça segment segment ilerlenir.
    async fn locate(&self, offset: u64) -> io::Result<(usize, Range<u64>)> {
        loop {
            let outcome = {
                let loc = self.ctx.locator.lock().expect("kilit");
                loc.resolve(offset..offset + 1)
            };
            match outcome {
                Ok(slices) => {
                    let index = slices[0].index;
                    let span = self
                        .ctx
                        .locator
                        .lock()
                        .expect("kilit")
                        .decoded_span(index)
                        .expect("decoded segment has a span");
                    return Ok((index, span));
                }
                Err(LocatorError::NeedSegments(indices)) => {
                    for index in indices {
                        self.ensure_located(index).await?;
                    }
                }
                Err(other) => return Err(io::Error::other(other.to_string())),
            }
        }
    }

    /// PAR2 onarım katmanını kurar. Kurulumdan sonra hasarlı bölgeler ağa
    /// çıkılmadan katmandan servis edilir.
    pub(crate) fn set_overlay(&self, overlay: Arc<crate::engine::repair::FileOverlay>) {
        *self.overlay.lock().expect("kilit") = Some(overlay);
    }

    /// Aralığı katman/ökün parçalarına böler. Katman yoksa tek ökün parçası.
    fn overlay_pieces(&self, range: Range<u64>) -> Vec<RangePiece> {
        let overlay = self.overlay.lock().expect("kilit").clone();
        let Some(overlay) = overlay else {
            return vec![RangePiece::Original(range)];
        };
        let mut pieces = Vec::new();
        let mut cursor = range.start;
        while cursor < range.end {
            if let Some((index, data)) = overlay.slice_covering(cursor) {
                let slice_start = index * overlay.slice_size;
                let take_end = (slice_start + overlay.slice_size)
                    .min(range.end)
                    .min(overlay.file_len);
                let skip = (cursor - slice_start) as usize;
                let take = ((take_end - cursor) as usize).min(data.len().saturating_sub(skip));
                pieces.push(RangePiece::Overlay {
                    data: Arc::clone(data),
                    skip,
                    take,
                });
                cursor = take_end;
            } else {
                let next = overlay.next_slice_start(cursor).min(range.end);
                pieces.push(RangePiece::Original(cursor..next));
                cursor = next;
            }
        }
        pieces
    }

    /// Arşiv başlığı gibi küçük, rastgele aralıkları bellek tamponuna okur.
    /// Ofset çözümü yine yalnız yEnc `begin/end` kayıtlarıyla yapılır.
    pub(crate) async fn read_range_bytes(&self, range: Range<u64>) -> io::Result<Vec<u8>> {
        let file_size = self.file_size().unwrap_or(0);
        if range.start >= range.end || range.end > file_size {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!(
                    "invalid source range {}..{} (size {file_size})",
                    range.start, range.end
                ),
            ));
        }

        let capacity = usize::try_from(range.end - range.start)
            .map_err(|_| io::Error::other("requested range does not fit in memory"))?;
        let mut output = Vec::with_capacity(capacity);
        for piece in self.overlay_pieces(range) {
            match piece {
                RangePiece::Overlay { data, skip, take } => {
                    output.extend_from_slice(&data[skip..skip + take]);
                }
                RangePiece::Original(sub) => {
                    output.extend_from_slice(&self.read_range_original(sub).await?);
                }
            }
        }
        Ok(output)
    }

    /// Katman dışı aralığı segmentlerden okur (katman öncesi tek yoldu).
    async fn read_range_original(&self, range: Range<u64>) -> io::Result<Vec<u8>> {
        let mut prefetch = PrefetchWindow::new(self.ctx.prefetch_depth);
        let mut output = Vec::with_capacity((range.end - range.start) as usize);
        let mut cursor = range.start;
        while cursor < range.end {
            let (index, span) = self.locate(cursor).await?;
            let seg_end = span.end.min(range.end);
            let data = self.segment_data(index).await?;
            let from = (cursor - span.start) as usize;
            let to = (seg_end - span.start) as usize;
            if span.end < range.end {
                self.advance_prefetch(&mut prefetch, index);
            }
            output.extend_from_slice(&data[from..to]);
            cursor = seg_end;
        }
        Ok(output)
    }
}

impl RangeSource for NntpByteSource {
    fn total_len(&self) -> u64 {
        self.file_size().unwrap_or(0)
    }

    fn content_type(&self) -> &str {
        self.content_type
    }

    async fn write_range<W>(&self, range: Range<u64>, out: &mut W) -> io::Result<()>
    where
        W: AsyncWrite + Unpin + Send,
    {
        for piece in self.overlay_pieces(range) {
            match piece {
                RangePiece::Overlay { data, skip, take } => {
                    out.write_all(&data[skip..skip + take]).await?;
                }
                RangePiece::Original(sub) => {
                    self.write_range_original(sub, out).await?;
                }
            }
        }
        Ok(())
    }
}

/// [`NntpByteSource::overlay_pieces`] çıktısı: katman dilimi veya ökün aralık.
enum RangePiece {
    Overlay {
        data: Arc<Vec<u8>>,
        skip: usize,
        take: usize,
    },
    Original(Range<u64>),
}

impl NntpByteSource {
    fn advance_prefetch(&self, window: &mut PrefetchWindow, index: usize) {
        window.advance(index, self.segment_count(), |next| {
            let ctx = Arc::clone(&self.ctx);
            async move {
                let _ = ctx.fetch_and_cache(next).await;
            }
        });
    }

    /// Katman dışı aralığı segment segment, tembel akışla yazar: her adımda
    /// cursor'ı içeren segmenti bulup yazarız. Player (mpv/media_kit)
    /// yeterince okuyup bağlantıyı kapatınca ilk `write_all` `BrokenPipe`
    /// döner ve gereksiz çekme durur.
    async fn write_range_original<W>(&self, range: Range<u64>, out: &mut W) -> io::Result<()>
    where
        W: AsyncWrite + Unpin + Send,
    {
        let mut prefetch = PrefetchWindow::new(self.ctx.prefetch_depth);
        let mut cursor = range.start;
        while cursor < range.end {
            let (index, span) = self.locate(cursor).await?;
            let seg_end = span.end.min(range.end);
            let data = self.segment_data(index).await?;
            if span.end < range.end {
                self.advance_prefetch(&mut prefetch, index);
            }
            let from = (cursor - span.start) as usize;
            let to = (seg_end - span.start) as usize;
            out.write_all(&data[from..to]).await?;
            cursor = seg_end;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn prefetch_stops_at_window_until_consumer_advances() {
        let fetched = Arc::new(Mutex::new(Vec::new()));
        let mut window = PrefetchWindow::new(4);
        let fetch = |index| {
            let fetched = Arc::clone(&fetched);
            async move {
                fetched.lock().unwrap().push(index);
            }
        };
        window.advance(0, 1000, fetch);
        while window.tasks.join_next().await.is_some() {}
        let mut actual = fetched.lock().unwrap().clone();
        actual.sort();
        assert_eq!(actual, vec![1, 2, 3, 4]);

        window.advance(1, 1000, fetch);
        while window.tasks.join_next().await.is_some() {}
        let mut actual = fetched.lock().unwrap().clone();
        actual.sort();
        assert_eq!(actual, vec![1, 2, 3, 4, 5]);
        window.advance(999, 1000, fetch);
        assert!(window.tasks.is_empty());
    }

    #[tokio::test]
    async fn dropping_request_aborts_pending_prefetch() {
        let (dropped, mut drops) = tokio::sync::mpsc::unbounded_channel();
        struct OnDrop(tokio::sync::mpsc::UnboundedSender<()>);
        impl Drop for OnDrop {
            fn drop(&mut self) {
                let _ = self.0.send(());
            }
        }
        let mut window = PrefetchWindow::new(4);
        window.advance(0, 100, |_| {
            let guard = OnDrop(dropped.clone());
            async move {
                let _guard = guard;
                std::future::pending::<()>().await;
            }
        });
        drop(window);
        for _ in 0..4 {
            tokio::time::timeout(Duration::from_secs(1), drops.recv())
                .await
                .unwrap()
                .unwrap();
        }
    }

    #[tokio::test]
    async fn cancelled_fetch_releases_inflight_claim() {
        let ctx = Arc::new(FetchContext {
            pool: TlsNntpConnector::new(super::super::nntp::ProviderConfig {
                host: "unused.invalid".into(),
                port: 563,
                username: "test".into(),
                password: "TESTPASS123".into(),
                max_connections: 1,
            })
            .into_pool(),
            locator: Mutex::new(SegmentLocator::from_nzb_file(
                &super::super::nzb::parse_nzb(include_str!(
                    "../../tests/fixtures/obfuscated-numbered-set.nzb"
                ))
                .unwrap()
                .files[0],
            )),
            cache: Mutex::new(SegmentCache::new(8)),
            inflight: Mutex::new(HashSet::from([0])),
            inflight_notify: Notify::new(),
            prefetch_depth: 4,
            cancellation: None,
        });
        let guard = InflightFetch {
            ctx: Arc::clone(&ctx),
            index: 0,
        };
        let task = tokio::spawn(async move {
            let _guard = guard;
            std::future::pending::<()>().await;
        });
        task.abort();
        let _ = task.await;
        assert!(ctx.inflight.lock().unwrap().is_empty());
    }

    #[test]
    fn cache_kapasiteyi_asinca_en_eskiyi_atar() {
        let mut cache = SegmentCache::new(2);
        cache.insert(0, Arc::new(vec![0]));
        cache.insert(1, Arc::new(vec![1]));
        cache.insert(2, Arc::new(vec![2])); // 0 atılmalı
        assert!(cache.get(0).is_none());
        assert!(cache.get(1).is_some());
        assert!(cache.get(2).is_some());
    }

    #[test]
    fn cache_ayni_indeksi_tekrar_eklemez() {
        let mut cache = SegmentCache::new(2);
        cache.insert(5, Arc::new(vec![5]));
        cache.insert(5, Arc::new(vec![9])); // yok sayılır
        assert_eq!(cache.get(5).unwrap().as_slice(), &[5]);
    }

    #[tokio::test]
    async fn body_okumasi_sonlu_zaman_asimi_dondurur() {
        let result = read_body_with_timeout(
            Duration::from_millis(5),
            std::future::pending::<Result<Vec<u8>, NntpError>>(),
        )
        .await;
        assert!(matches!(
            result,
            Err(NntpError::Timeout {
                operation: "NNTP BODY"
            })
        ));
    }
}
