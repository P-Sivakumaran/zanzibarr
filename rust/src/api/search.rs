//! Newznab indexer arama API'si (flutter_rust_bridge).
//!
//! Dart, güvenli depodan okuduğu indexer adresini ve API anahtarını verir;
//! Rust caps keşfi, metin araması ve NZB indirme işlerini yürütür. İndirilen
//! NZB geçici dizine yazılır ve yolu döndürülür — oynatma mevcut
//! [`crate::api::streaming`] akışıyla devam eder.
//!
//! Gizlilik kuralı: API anahtarı ve anahtar taşıyan URL'ler yalnızca bellek
//! içinde akar; hiçbir DTO `Debug` türetmez, hata metinleri URL/gövde
//! içermez.

use std::time::Duration;

use crate::engine::http::{self, HttpError};
use crate::engine::newznab::{self, MediaKind};

use super::streaming::RUNTIME;

const SEARCH_TIMEOUT: Duration = Duration::from_secs(20);
const DOWNLOAD_TIMEOUT: Duration = Duration::from_secs(60);
const MAX_SEARCH_BYTES: usize = 8 * 1024 * 1024;
const MAX_NZB_BYTES: usize = 64 * 1024 * 1024;

/// Dart'tan gelen indexer yapılandırması.
pub struct IndexerConfigDto {
    pub structured: Option<StructuredSearchDto>,
    /// Stable profile identity; display names need not be unique.
    pub id: Option<String>,
    /// Ör. `https://miatrix.example` (sonunda `/api` olabilir ya da olmayabilir).
    pub base_url: String,
    pub api_key: String,
    /// Kullanıcının bu profile verdiği ad; sonuçlarda kaynak rozeti ve
    /// kısmi-hata mesajlarında ("X indexer yanıt vermedi") kullanılır.
    pub nickname: String,
}

/// Canonical identity plus this indexer's advertised search parameters.
/// Empty parameters deliberately select the ordinary title fallback.
#[derive(Clone)]
pub struct StructuredSearchDto {
    pub kind: String,
    pub imdb_id: Option<String>,
    pub tvdb_id: Option<String>,
    pub season: Option<u32>,
    pub episode: Option<u32>,
    pub supported_params: Vec<String>,
}

/// `?t=caps` özeti; UI hangi arama türlerinin açık olduğunu buna göre gösterir.
pub struct IndexerCapsDto {
    pub movie_search_params: Option<Vec<String>>,
    pub tv_search_params: Option<Vec<String>>,
    pub server_title: Option<String>,
    pub search_available: bool,
    pub tv_search_available: bool,
    pub movie_search_available: bool,
}

/// Tek arama sonucu. `nzb_url` API anahtarı içerebilir; loglanmamalıdır.
pub struct SearchItemDto {
    pub imdb_id: Option<String>,
    pub source_id: Option<String>,
    pub title: String,
    pub nzb_url: String,
    pub info_url: Option<String>,
    pub size_bytes: Option<u64>,
    pub published_epoch_secs: Option<i64>,
    /// Rust tarafında hazırlanan görüntü rozetleri: ["2160p","HEVC","DV",…].
    pub badges: Vec<String>,
    /// "movie" | "tv" | "other" — UI simgesi için.
    pub media_kind: String,
    pub season: Option<u32>,
    pub episode: Option<u32>,
    pub year: Option<u32>,
    pub group: Option<String>,
    /// Bu sonucun geldiği indexer'ın takma adı (çoklu-indexer aramada
    /// kaynak rozeti için).
    pub source_indexer: String,
}

pub struct SearchPageDto {
    pub total: Option<u64>,
    pub items: Vec<SearchItemDto>,
}

/// [`newznab_search_many`] sonucu: birleşmiş/tekilleştirilmiş sayfa artı
/// yanıt veremeyen indexer'ların takma adları (arama tamamen başarısız
/// olmaz; UI "X / Y indexer yanıt verdi" gösterebilir).
pub struct SearchManyResultDto {
    pub page: SearchPageDto,
    pub failed_indexers: Vec<String>,
    /// One cursor per input config; u32::MAX denotes an exhausted source.
    pub next_offsets: Option<Vec<u32>>,
    pub has_more: Option<bool>,
}

fn map_http_error(error: HttpError) -> String {
    error.to_string()
}

fn fetch_checked(url: &str, max_bytes: usize, timeout: Duration) -> Result<String, String> {
    RUNTIME.block_on(async {
        let response = http::http_get(url, max_bytes, timeout)
            .await
            .map_err(map_http_error)?;
        if !(200..300).contains(&response.status) {
            return Err(format!("indexer returned HTTP {}", response.status));
        }
        String::from_utf8(response.body).map_err(|_| "indexer response is not UTF-8".to_string())
    })
}

/// Indexer'ın yeteneklerini sorgular (`?t=caps`). Bağlantı ve API anahtarı
/// doğrulaması için de kullanılır.
pub fn newznab_check_caps(config: IndexerConfigDto) -> Result<IndexerCapsDto, String> {
    let url = newznab::build_api_url(
        &config.base_url,
        &[("t", "caps"), ("apikey", &config.api_key)],
    );
    let body = fetch_checked(&url, MAX_SEARCH_BYTES, SEARCH_TIMEOUT)?;
    let caps = newznab::parse_caps(&body).map_err(|error| error.to_string())?;
    Ok(IndexerCapsDto {
        movie_search_params: caps
            .movie_search
            .as_ref()
            .map(|s| s.supported_params.clone()),
        tv_search_params: caps.tv_search.as_ref().map(|s| s.supported_params.clone()),
        server_title: caps.server_title,
        search_available: caps.search.as_ref().is_some_and(|s| s.available),
        tv_search_available: caps.tv_search.as_ref().is_some_and(|s| s.available),
        movie_search_available: caps.movie_search.as_ref().is_some_and(|s| s.available),
    })
}

/// Metin araması yapar (`?t=search&q=…`). Sonuçlar release rozetleriyle
/// birlikte döner; liste sırası indexer'ın sırasıdır.
pub fn newznab_search(
    config: IndexerConfigDto,
    query: String,
    limit: u32,
    offset: u32,
) -> Result<SearchPageDto, String> {
    let limit = limit.clamp(1, 100).to_string();
    let offset = offset.to_string();
    let mut params = search_query_params(&query, config.structured.as_ref())?;
    params.extend([
        ("apikey".into(), config.api_key.clone()),
        ("limit".into(), limit),
        ("offset".into(), offset),
    ]);
    let pairs: Vec<(&str, &str)> = params
        .iter()
        .map(|(key, value)| (key.as_str(), value.as_str()))
        .collect();
    let url = newznab::build_api_url(&config.base_url, &pairs);
    let body = fetch_checked(&url, MAX_SEARCH_BYTES, SEARCH_TIMEOUT)?;
    let page = newznab::parse_search_response(&body).map_err(|error| error.to_string())?;

    let source = config.nickname.clone();
    let items = page
        .items
        .into_iter()
        .map(|item| map_item(item, source.clone()))
        .collect();
    Ok(SearchPageDto {
        total: page.total,
        items,
    })
}

/// Rust'ın dahili [`newznab::SearchItem`]'ini Dart DTO'suna çevirir; hem tek
/// hem çoklu indexer aramasında ortak kullanılır.
fn map_item(item: newznab::SearchItem, source_indexer: String) -> SearchItemDto {
    let kind = item.release.media_kind(&item.categories, item.season);
    SearchItemDto {
        imdb_id: item.imdb_id.as_deref().and_then(normalize_imdb_id),
        source_id: None,
        title: item.title,
        nzb_url: item.nzb_url,
        info_url: item.info_url,
        size_bytes: item.size_bytes,
        published_epoch_secs: item.published_epoch_secs,
        badges: item.release.badges(),
        media_kind: match kind {
            MediaKind::Movie => "movie",
            MediaKind::Tv => "tv",
            MediaKind::Other => "other",
        }
        .to_string(),
        season: item.season,
        episode: item.episode,
        year: item.release.year,
        group: item.release.group,
        source_indexer,
    }
}

async fn fetch_checked_async(
    url: &str,
    max_bytes: usize,
    timeout: Duration,
) -> Result<String, String> {
    let response = http::http_get(url, max_bytes, timeout)
        .await
        .map_err(map_http_error)?;
    if !(200..300).contains(&response.status) {
        return Err(format!("indexer returned HTTP {}", response.status));
    }
    String::from_utf8(response.body).map_err(|_| "indexer response is not UTF-8".to_string())
}

async fn fetch_search_items_async(
    config: &IndexerConfigDto,
    query: &str,
    limit: u32,
    offset: u32,
) -> Result<newznab::SearchPage, String> {
    let limit = limit.clamp(1, 100).to_string();
    let offset = offset.to_string();
    let mut params = search_query_params(query, config.structured.as_ref())?;
    params.extend([
        ("apikey".into(), config.api_key.clone()),
        ("limit".into(), limit),
        ("offset".into(), offset),
    ]);
    let pairs: Vec<(&str, &str)> = params
        .iter()
        .map(|(key, value)| (key.as_str(), value.as_str()))
        .collect();
    let url = newznab::build_api_url(&config.base_url, &pairs);
    let body = fetch_checked_async(&url, MAX_SEARCH_BYTES, SEARCH_TIMEOUT).await?;
    let page = newznab::parse_search_response(&body).map_err(|error| error.to_string())?;
    Ok(page)
}

fn normalize_imdb_id(id: &str) -> Option<String> {
    let trimmed = id.trim();
    let digits = trimmed.strip_prefix("tt").unwrap_or(trimmed);
    ((7..=10).contains(&digits.len()) && digits.bytes().all(|b| b.is_ascii_digit()))
        .then(|| format!("tt{digits}"))
}

fn search_query_params(
    query: &str,
    structured: Option<&StructuredSearchDto>,
) -> Result<Vec<(String, String)>, String> {
    let fallback = || vec![("t".into(), "search".into()), ("q".into(), query.into())];
    let Some(search) = structured else {
        return Ok(fallback());
    };
    if search.kind == "adult" {
        if search.imdb_id.is_some()
            || search.tvdb_id.is_some()
            || search.season.is_some()
            || search.episode.is_some()
        {
            return Err("catalog IDs cannot constrain adult release search".into());
        }
        let mut params = fallback();
        params.push(("cat".into(), "6000".into()));
        return Ok(params);
    }
    if !matches!(search.kind.as_str(), "movie" | "tv") {
        return Err("invalid search type".into());
    }
    if search.episode.is_some() && search.season.is_none() {
        return Err("episode requires a season".into());
    }
    if search.kind == "movie"
        && (search.season.is_some() || search.episode.is_some() || search.tvdb_id.is_some())
    {
        return Err("TV fields cannot be used for movies".into());
    }
    let imdb = search
        .imdb_id
        .as_deref()
        .map(|id| normalize_imdb_id(id).ok_or("invalid IMDb ID"))
        .transpose()?;
    if search.tvdb_id.as_ref().is_some_and(|id| {
        id.is_empty()
            || id.len() > 10
            || id.starts_with('0')
            || !id.bytes().all(|b| b.is_ascii_digit())
    }) {
        return Err("invalid TVDB ID".into());
    }
    if search.season.is_some_and(|n| n > 9999) || search.episode.is_some_and(|n| n == 0 || n > 9999)
    {
        return Err("invalid season or episode".into());
    }
    let supports = |key: &str| {
        search
            .supported_params
            .iter()
            .any(|p| p.eq_ignore_ascii_case(key))
    };
    if (search.season.is_some() && !supports("season"))
        || (search.episode.is_some() && !supports("ep"))
    {
        return Ok(fallback());
    }
    let mut params = vec![(
        "t".into(),
        if search.kind == "movie" {
            "movie"
        } else {
            "tvsearch"
        }
        .into(),
    )];
    if let Some(id) = imdb.filter(|_| supports("imdbid")) {
        params.push(("imdbid".into(), id[2..].into()));
    } else if let Some(id) = search
        .tvdb_id
        .as_ref()
        .filter(|_| search.kind == "tv" && supports("tvdbid"))
    {
        params.push(("tvdbid".into(), id.clone()));
    } else {
        return Ok(fallback());
    }
    if let Some(season) = search.season {
        params.push(("season".into(), season.to_string()));
    }
    if let Some(episode) = search.episode {
        params.push(("ep".into(), episode.to_string()));
    }
    Ok(params)
}

/// Birden çok indexer'ı paralel sorgular, sonuçları birleştirip
/// tekilleştirir. Tek bir indexer'ın zaman aşımına uğraması/hata vermesi
/// aramanın tamamını düşürmez — o indexer `failed_indexers`'a eklenir,
/// diğerlerinin sonuçları döner.
pub fn newznab_search_many(
    configs: Vec<IndexerConfigDto>,
    query: String,
    limit: u32,
    offset: u32,
    offsets: Option<Vec<u32>>,
) -> SearchManyResultDto {
    RUNTIME.block_on(async move {
        let mut set = tokio::task::JoinSet::new();
        let mut tasks = std::collections::HashMap::new();
        let mut next_offsets: Vec<u32> = (0..configs.len())
            .map(|i| {
                offsets
                    .as_ref()
                    .and_then(|values| values.get(i))
                    .copied()
                    .unwrap_or(offset)
            })
            .collect();
        let names: Vec<String> = configs.iter().map(|c| c.nickname.clone()).collect();
        let ids: Vec<Option<String>> = configs.iter().map(|c| c.id.clone()).collect();
        for (index, config) in configs.into_iter().enumerate() {
            let source_offset = next_offsets[index];
            if source_offset == u32::MAX {
                continue;
            }
            let query = query.clone();
            let handle = set.spawn(async move {
                let result = fetch_search_items_async(&config, &query, limit, source_offset).await;
                (index, result)
            });
            tasks.insert(handle.id(), index);
        }

        let mut tagged_items: Vec<(String, newznab::SearchItem)> = Vec::new();
        let mut failed_indexers = Vec::new();
        let mut pages = Vec::new();

        while let Some(joined) = set.join_next().await {
            match joined {
                Ok(page) => pages.push(page),
                Err(error) => {
                    if let Some(&index) = tasks.get(&error.id()) {
                        pages.push((index, Err("indexer task failed".into())));
                    }
                }
            }
        }
        // Keep deduplication preference deterministic regardless of response order.
        pages.sort_by_key(|(index, _)| *index);
        let mut total = None;
        for (index, result) in pages {
            match result {
                Ok(page) => {
                    let next = next_offsets[index].saturating_add(page.raw_item_count);
                    let exhausted = page.raw_item_count == 0
                        || page.total.is_some_and(|count| u64::from(next) >= count);
                    next_offsets[index] = if exhausted { u32::MAX } else { next };
                    if names.len() == 1 {
                        total = page.total;
                    }
                    tagged_items
                        .extend(page.items.into_iter().map(|item| (index.to_string(), item)));
                }
                Err(_) => failed_indexers.push(names[index].clone()),
            }
        }

        let deduped = newznab::dedup_items_with_source(tagged_items);
        let items = deduped
            .into_iter()
            .map(|(source, item)| {
                let index: usize = source.parse().expect("internal source index");
                let mut item = map_item(item, names[index].clone());
                item.source_id = ids[index].clone();
                item
            })
            .collect();

        SearchManyResultDto {
            page: SearchPageDto { total, items },
            failed_indexers,
            has_more: Some(next_offsets.iter().any(|&cursor| cursor != u32::MAX)),
            next_offsets: Some(next_offsets),
        }
    })
}

// Download links can point at external CDNs. Never append this indexer's key
// outside its exact configured origin.
fn authenticated_download_url(config: &IndexerConfigDto, nzb_url: String) -> String {
    if nzb_url.contains("apikey=")
        || config.api_key.is_empty()
        || !http::same_origin(&config.base_url, &nzb_url)
    {
        nzb_url
    } else {
        let separator = if nzb_url.contains('?') { '&' } else { '?' };
        format!(
            "{nzb_url}{separator}apikey={}",
            newznab::percent_encode(&config.api_key)
        )
    }
}

/// Arama sonucunun NZB'sini geçici dizine indirir ve dosya yolunu döndürür.
/// Yanıtın gerçekten NZB olduğu kök öğe kokusuyla doğrulanır; HTML hata
/// sayfaları oynatıcıya kadar ilerleyemez.
///
/// `download_dir`: Dart tarafının `path_provider` ile verdiği uygulama önbellek
/// dizini. Android'de `std::env::temp_dir()` kullanılamaz (`TMPDIR` yok, `/tmp`
/// yazılamaz — Android TV raporu); None/boş ise masaüstünde çalışan eski
/// davranışa (sistem temp + `zanzibarr-nzb`) düşülür.
pub fn newznab_download_nzb(
    config: IndexerConfigDto,
    nzb_url: String,
    suggested_name: String,
    download_dir: Option<String>,
) -> Result<String, String> {
    let url = authenticated_download_url(&config, nzb_url);

    let response = RUNTIME
        .block_on(http::http_get_with_origin(
            &url,
            MAX_NZB_BYTES,
            DOWNLOAD_TIMEOUT,
            &config.base_url,
        ))
        .map_err(map_http_error)?;
    if !(200..300).contains(&response.status) {
        return Err(format!("indexer returned HTTP {}", response.status));
    }
    let body = String::from_utf8(response.body)
        .map_err(|_| "indexer response is not UTF-8".to_string())?;
    let head: String = body.chars().take(4096).collect();
    let looks_nzb = head.contains("<nzb") || head.contains("<!DOCTYPE nzb");
    if !looks_nzb {
        return Err("downloaded content is not an NZB".to_string());
    }

    let dir = download_dir_path(download_dir);
    std::fs::create_dir_all(&dir)
        .map_err(|error| format!("could not create temp directory: {error}"))?;
    let filename = format!(
        "{}-{}.nzb",
        sanitize_filename(&suggested_name),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0)
    );
    let path = dir.join(filename);
    std::fs::write(&path, body).map_err(|error| format!("could not write NZB: {error}"))?;
    Ok(path.to_string_lossy().into_owned())
}

/// NZB indirme dizinini seçer: Dart'ın verdiği geçerli yol öncelikli; yoksa
/// sistem temp'i altında `zanzibarr-nzb` (masaüstü/CLI davranışı).
fn download_dir_path(download_dir: Option<String>) -> std::path::PathBuf {
    download_dir
        .filter(|dir| !dir.trim().is_empty())
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|| std::env::temp_dir().join("zanzibarr-nzb"))
}

/// Dosya adını platform-güvenli karakterlere indirger (en çok 60 karakter).
fn sanitize_filename(name: &str) -> String {
    let sanitized: String = name
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || matches!(c, '-' | '_' | '.') {
                c
            } else {
                '_'
            }
        })
        .take(60)
        .collect();
    let sanitized = sanitized.trim_matches(['.', '_']).to_string();
    if sanitized.is_empty() {
        "arama-sonucu".to_string()
    } else {
        sanitized
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn selection(kind: &str, params: &[&str]) -> StructuredSearchDto {
        StructuredSearchDto {
            kind: kind.into(),
            imdb_id: Some("tt0133093".into()),
            tvdb_id: None,
            season: None,
            episode: None,
            supported_params: params.iter().map(|p| p.to_string()).collect(),
        }
    }

    #[test]
    fn download_credentials_stay_at_configured_origin() {
        let config = IndexerConfigDto {
            structured: None,
            id: None,
            nickname: "Test".into(),
            base_url: "https://indexer.example".into(),
            api_key: "TESTPASS123".into(),
        };
        assert_eq!(
            authenticated_download_url(&config, "https://indexer.example/get?id=1".into()),
            "https://indexer.example/get?id=1&apikey=TESTPASS123"
        );
        for url in [
            "https://cdn.example/get?id=1",
            "http://indexer.example/get",
            "https://indexer.example:444/get",
        ] {
            assert_eq!(authenticated_download_url(&config, url.into()), url);
        }
        let supplied = "https://indexer.example/get?apikey=TESTPASS123";
        assert_eq!(
            authenticated_download_url(&config, supplied.into()),
            supplied
        );
    }

    #[test]
    fn adult_search_uses_text_and_category_without_catalog_ids() {
        let mut adult = selection("adult", &[]);
        assert!(search_query_params("Catalog title", Some(&adult)).is_err());
        adult.imdb_id = None;
        assert_eq!(
            search_query_params("Catalog title", Some(&adult)).unwrap(),
            vec![
                ("t".into(), "search".into()),
                ("q".into(), "Catalog title".into()),
                ("cat".into(), "6000".into())
            ]
        );
        adult.season = Some(1);
        assert!(search_query_params("Catalog title", Some(&adult)).is_err());
    }

    #[test]
    fn structured_movie_uses_advertised_id_without_tt_and_keeps_zeroes() {
        let params =
            search_query_params("The Matrix 1999", Some(&selection("movie", &["IMDBID"]))).unwrap();
        assert_eq!(
            params,
            vec![
                ("t".into(), "movie".into()),
                ("imdbid".into(), "0133093".into())
            ]
        );
    }

    #[test]
    fn structured_tv_uses_tvdb_and_explicit_episode() {
        let mut search = selection("tv", &["tvdbid", "season", "ep"]);
        search.tvdb_id = Some("12345".into());
        search.season = Some(0);
        search.episode = Some(2);
        let params = search_query_params("A Show S00E02", Some(&search)).unwrap();
        assert_eq!(
            params,
            vec![
                ("t".into(), "tvsearch".into()),
                ("tvdbid".into(), "12345".into()),
                ("season".into(), "0".into()),
                ("ep".into(), "2".into())
            ]
        );
    }

    #[test]
    fn unsupported_identity_or_episode_falls_back_to_complete_title_query() {
        let mut search = selection("tv", &["imdbid", "season"]);
        search.season = Some(1);
        search.episode = Some(2);
        let fallback = search_query_params("A Show S01E02", None).unwrap();
        assert_eq!(
            search_query_params("A Show S01E02", Some(&search)).unwrap(),
            fallback
        );
        search.supported_params.clear();
        assert_eq!(
            search_query_params("A Show S01E02", Some(&search)).unwrap(),
            fallback
        );
    }

    #[test]
    fn structured_search_rejects_invalid_identity_and_episode_constraints() {
        let mut search = selection("tv", &["imdbid", "season", "ep"]);
        search.episode = Some(2);
        assert!(search_query_params("Show", Some(&search)).is_err());
        search.season = Some(1);
        search.imdb_id = Some("tt123&apikey=TESTPASS123".into());
        let error = search_query_params("Show", Some(&search)).unwrap_err();
        assert_eq!(error, "invalid IMDb ID");
        search.imdb_id = Some("tt0133093".into());
        search.kind = "movie".into();
        assert!(search_query_params("Film", Some(&search)).is_err());
    }

    #[test]
    fn result_identity_is_normalized_and_invalid_ids_are_dropped() {
        let xml = r#"<rss><channel><item><title>Film</title><link>https://example.test/nzb</link><newznab:attr name="imdb" value="0133093"/></item></channel></rss>"#;
        let page = newznab::parse_search_response(xml).unwrap();
        assert_eq!(
            map_item(page.items.into_iter().next().unwrap(), "source".into())
                .imdb_id
                .as_deref(),
            Some("tt0133093")
        );
        assert_eq!(normalize_imdb_id("garbage"), None);
    }

    fn mock_indexer(
        pages: Vec<(u32, &'static str)>,
        id: &str,
    ) -> (IndexerConfigDto, std::thread::JoinHandle<()>) {
        use std::io::{Read, Write};
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let address = listener.local_addr().unwrap();
        let handle = std::thread::spawn(move || {
            for (offset, body) in pages {
                let deadline = std::time::Instant::now() + Duration::from_secs(5);
                let mut stream = loop {
                    match listener.accept() {
                        Ok((stream, _)) => break stream,
                        Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                            assert!(
                                std::time::Instant::now() < deadline,
                                "missing indexer request"
                            );
                            std::thread::sleep(Duration::from_millis(5));
                        }
                        Err(error) => panic!("{error}"),
                    }
                };
                stream
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                let mut request = Vec::new();
                let mut byte = [0];
                while !request.ends_with(b"\r\n\r\n") {
                    stream.read_exact(&mut byte).unwrap();
                    request.push(byte[0]);
                }
                let request = String::from_utf8(request).unwrap();
                assert!(
                    request.contains(&format!("offset={offset}")),
                    "incorrect source cursor"
                );
                write!(
                    stream,
                    "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    body.len(),
                    body
                )
                .unwrap();
            }
        });
        (
            IndexerConfigDto {
                structured: None,
                id: Some(id.into()),
                base_url: format!("http://{address}"),
                api_key: "TESTPASS123".into(),
                nickname: "Shared name".into(),
            },
            handle,
        )
    }

    const FIRST: &str = r#"<rss xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/"><channel><newznab:response offset="0" total="2"/><item><title>Film.2024</title><link>http://example.test/one</link><newznab:attr name="size" value="1000"/></item></channel></rss>"#;
    const SECOND: &str = r#"<rss xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/"><channel><newznab:response offset="1" total="2"/><item><title>Other.2024</title><link>http://example.test/two</link><newznab:attr name="size" value="2000"/></item></channel></rss>"#;
    const ERROR: &str = r#"<error code="100" description="TESTPASS123"/>"#;

    #[test]
    fn fanout_cursors_advance_before_dedup_and_preserve_identity() {
        let (a, server_a) = mock_indexer(vec![(0, FIRST), (1, SECOND)], "a");
        let (b, server_b) = mock_indexer(vec![(0, FIRST), (1, SECOND)], "b");
        let again = [&a, &b]
            .into_iter()
            .map(|c| IndexerConfigDto {
                structured: c.structured.clone(),
                id: c.id.clone(),
                base_url: c.base_url.clone(),
                api_key: c.api_key.clone(),
                nickname: c.nickname.clone(),
            })
            .collect();
        let first = newznab_search_many(vec![a, b], "film".into(), 50, 0, None);
        assert_eq!(first.page.items.len(), 1);
        assert_eq!(first.page.items[0].source_id.as_deref(), Some("a"));
        assert_eq!(first.next_offsets, Some(vec![1, 1]));
        assert_eq!(first.has_more, Some(true));
        assert_eq!(first.page.total, None);
        let second = newznab_search_many(again, "film".into(), 50, 0, first.next_offsets);
        assert_eq!(second.page.items.len(), 1);
        assert_eq!(second.page.items[0].title, "Other.2024");
        assert_eq!(second.next_offsets, Some(vec![u32::MAX, u32::MAX]));
        assert_eq!(second.has_more, Some(false));
        server_a.join().unwrap();
        server_b.join().unwrap();
    }

    #[test]
    fn fanout_partial_errors_are_isolated_and_do_not_advance_failed_cursor() {
        let (a, server_a) = mock_indexer(vec![(0, FIRST)], "a");
        let (b, server_b) = mock_indexer(vec![(0, ERROR)], "b");
        let result = newznab_search_many(vec![a, b], "film".into(), 50, 0, None);
        assert_eq!(result.page.items.len(), 1);
        assert_eq!(result.failed_indexers, vec!["Shared name"]);
        assert_eq!(result.next_offsets, Some(vec![1, 0]));
        server_a.join().unwrap();
        server_b.join().unwrap();
    }

    #[test]
    fn fanout_cursors_count_records_without_download_links() {
        const UNUSABLE: &str =
            r#"<rss><channel><item><title>Missing link</title></item></channel></rss>"#;
        let (config, server) = mock_indexer(vec![(0, UNUSABLE), (1, SECOND)], "a");
        let again = IndexerConfigDto {
            structured: None,
            id: config.id.clone(),
            base_url: config.base_url.clone(),
            api_key: config.api_key.clone(),
            nickname: config.nickname.clone(),
        };
        let first = newznab_search_many(vec![config], "film".into(), 50, 0, None);
        assert!(first.page.items.is_empty());
        assert_eq!(first.next_offsets, Some(vec![1]));
        assert_eq!(first.has_more, Some(true));
        let second = newznab_search_many(vec![again], "film".into(), 50, 0, first.next_offsets);
        assert_eq!(second.page.items.len(), 1);
        assert_eq!(second.has_more, Some(false));
        server.join().unwrap();
    }

    #[test]
    fn dosya_adi_temizligi() {
        assert_eq!(
            sanitize_filename("Fight.Club.1999-GROUP"),
            "Fight.Club.1999-GROUP"
        );
        assert_eq!(
            sanitize_filename("a/b\\c:d*e?f\"g<h>i|j"),
            "a_b_c_d_e_f_g_h_i_j"
        );
        assert_eq!(sanitize_filename("   "), "arama-sonucu");
        assert_eq!(sanitize_filename("...___"), "arama-sonucu");
        assert_eq!(sanitize_filename(&"x".repeat(200)).len(), 60);
    }

    #[test]
    fn indirme_dizini_secimi() {
        // Dart'ın verdiği dizin aynen kullanılır.
        assert_eq!(
            download_dir_path(Some("/data/user/0/app/cache".into())),
            std::path::PathBuf::from("/data/user/0/app/cache")
        );
        // Boş/boşluklu dizin ve None sistem temp'ine düşer.
        let fallback = std::env::temp_dir().join("zanzibarr-nzb");
        assert_eq!(download_dir_path(None), fallback);
        assert_eq!(download_dir_path(Some("   ".into())), fallback);
    }
}
