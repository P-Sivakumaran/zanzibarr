//! Minimal HTTP/1.1 GET istemcisi.
//!
//! Indexer API çağrıları (Newznab caps/arama) ve NZB indirme tek atımlık
//! HTTPS GET'lerdir. reqwest gibi yeni bir bağımlılık eklemek yerine mevcut
//! tokio + rustls yığını üzerinde küçük bir istemci tutulur; gzip istenmez
//! (`Accept-Encoding: identity`), her istek yeni bağlantıdır
//! (`Connection: close`).
//!
//! Gizlilik kuralı: URL'ler sorgu kısmında API anahtarı taşıyabilir. Hata
//! türleri URL, yanıt gövdesi veya `Location` başlığı içermez; yalnızca
//! statik bağlam ve durum kodu taşır.

use std::io;
use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;
use std::time::Duration;

use thiserror::Error;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufReader};
use tokio::net::{lookup_host, TcpStream};
use tokio_rustls::rustls;
use tokio_rustls::rustls::pki_types::ServerName;
use tokio_rustls::TlsConnector;
use url::{Host, Url};

const MAX_HEADER_BYTES: usize = 64 * 1024;
const MAX_REDIRECTS: u32 = 5;
const USER_AGENT: &str = "zanzibarr (+https://github.com/P-Sivakumaran/zanzibarr)";

#[derive(Debug, Error)]
pub enum HttpError {
    #[error("invalid URL: {0}")]
    InvalidUrl(&'static str),
    #[error("network error: {0}")]
    Io(#[from] io::Error),
    #[error("TLS handshake failed: {0}")]
    Tls(String),
    #[error("malformed HTTP response: {0}")]
    Malformed(&'static str),
    #[error("response size limit exceeded (limit {limit} bytes)")]
    TooLarge { limit: usize },
    #[error("too many redirects")]
    TooManyRedirects,
    #[error("request timed out")]
    Timeout,
}

pub struct HttpResponse {
    pub status: u16,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

impl HttpResponse {
    /// Başlık değerini büyük/küçük harf duyarsız arar.
    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(key, _)| key.eq_ignore_ascii_case(name))
            .map(|(_, value)| value.as_str())
    }
}

// URL objects may contain API keys: deliberately do not implement Debug.
struct ParsedUrl {
    url: Url,
    https: bool,
    host: String,
    port: u16,
    target: String,
}

fn validate_url_text(input: &str) -> Result<(), HttpError> {
    if input.bytes().any(|b| b <= 0x20 || b == 0x7f || b == b'\\') {
        return Err(HttpError::InvalidUrl("whitespace, controls or backslash"));
    }
    Ok(())
}

fn parse_url(input: &str) -> Result<ParsedUrl, HttpError> {
    validate_url_text(input)?;
    // Reject parser recovery of malformed authorities such as https:///host.
    let rest = input
        .split_once("://")
        .filter(|(scheme, _)| matches!(*scheme, "http" | "https"))
        .map(|(_, rest)| rest)
        .ok_or(HttpError::InvalidUrl("scheme must be http/https"))?;
    let authority = rest.split(['/', '?', '#']).next().unwrap_or_default();
    if authority.is_empty() || authority.contains('@') {
        return Err(HttpError::InvalidUrl("invalid authority or userinfo"));
    }
    let mut url = Url::parse(input).map_err(|_| HttpError::InvalidUrl("malformed URL"))?;
    if !url.username().is_empty() || url.password().is_some() {
        return Err(HttpError::InvalidUrl("userinfo is not supported"));
    }
    url.set_fragment(None);
    let host = match url.host() {
        Some(Host::Domain(name)) => name.to_string(),
        Some(Host::Ipv4(ip)) => ip.to_string(),
        Some(Host::Ipv6(ip)) => ip.to_string(),
        None => return Err(HttpError::InvalidUrl("host is empty")),
    };
    let port = url
        .port_or_known_default()
        .filter(|p| *p != 0)
        .ok_or(HttpError::InvalidUrl("invalid port"))?;
    let mut target = url.path().to_string();
    if let Some(query) = url.query() {
        target.push('?');
        target.push_str(query);
    }
    Ok(ParsedUrl {
        https: url.scheme() == "https",
        url,
        host,
        port,
        target,
    })
}

fn resolve_redirect(base: &ParsedUrl, location: &str) -> Result<String, HttpError> {
    validate_url_text(location)?;
    if location.is_empty() {
        return Err(HttpError::Malformed("empty Location header"));
    }
    // Check raw absolute authorities before URL normalization can erase userinfo.
    if location.contains("://") {
        parse_url(location)?;
    }
    if location.starts_with("//") {
        parse_url(&format!("{}:{location}", base.url.scheme()))?;
    }
    let joined = base
        .url
        .join(location)
        .map_err(|_| HttpError::InvalidUrl("malformed redirect"))?;
    let next = parse_url(joined.as_str())?;
    if base.https && !next.https {
        return Err(HttpError::InvalidUrl("HTTPS downgrade is not allowed"));
    }
    Ok(next.url.to_string())
}

/// Only a configured indexer's exact origin can receive its configured key.
pub fn same_origin(left: &str, right: &str) -> bool {
    match (parse_url(left), parse_url(right)) {
        (Ok(left), Ok(right)) => left.url.origin() == right.url.origin(),
        _ => false,
    }
}

fn private_address(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => ip.is_private() || ip.is_loopback(),
        IpAddr::V6(ip) => ip
            .to_ipv4_mapped()
            .map(|v| private_address(v.into()))
            .unwrap_or(ip.is_loopback() || (ip.segments()[0] & 0xfe00) == 0xfc00),
    }
}

fn forbidden_address(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => {
            let octets = ip.octets();
            ip.is_unspecified()
                || ip.is_multicast()
                || ip.is_link_local()
                || ip.is_broadcast()
                || octets[0] == 0
                || octets[0] >= 240
                || (octets[0] == 100 && (64..=127).contains(&octets[1]))
                || (octets[0] == 198 && (18..=19).contains(&octets[1]))
        }
        IpAddr::V6(ip) => ip
            .to_ipv4_mapped()
            .map(|v| forbidden_address(v.into()))
            .unwrap_or(
                ip.is_unspecified() || ip.is_multicast() || (ip.segments()[0] & 0xffc0) == 0xfe80,
            ),
    }
}

fn address_allowed(ip: IpAddr, same_origin: bool, granted: &[IpAddr]) -> bool {
    !forbidden_address(ip) && (!private_address(ip) || (same_origin && granted.contains(&ip)))
}

/// Kök sertifikalar `webpki-roots`'tan gelir (platform bağımsız) — NNTP
/// bağlayıcısıyla aynı yaklaşım.
fn tls_connector() -> TlsConnector {
    let mut roots = rustls::RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let config = rustls::ClientConfig::builder()
        .with_root_certificates(roots)
        .with_no_client_auth();
    TlsConnector::from(Arc::new(config))
}

/// Verilen URL'ye GET atar; 3xx yönlendirmeleri en çok [`MAX_REDIRECTS`]
/// kez izler. Son yanıtı (2xx/4xx/5xx) olduğu gibi döndürür — durum kodunun
/// yorumu çağırana aittir.
pub async fn http_get(
    url: &str,
    max_bytes: usize,
    timeout: Duration,
) -> Result<HttpResponse, HttpError> {
    // Calls for configured indexer endpoints explicitly grant their LAN origin.
    http_get_with_origin(url, max_bytes, timeout, url).await
}

pub async fn http_get_with_origin(
    url: &str,
    max_bytes: usize,
    timeout: Duration,
    configured_origin: &str,
) -> Result<HttpResponse, HttpError> {
    match tokio::time::timeout(timeout, http_get_inner(url, max_bytes, configured_origin)).await {
        Ok(result) => result,
        Err(_) => Err(HttpError::Timeout),
    }
}

async fn http_get_inner(
    url: &str,
    max_bytes: usize,
    configured_origin: &str,
) -> Result<HttpResponse, HttpError> {
    parse_url(url)?;
    let configured = parse_url(configured_origin)?;
    // Resolve the granted origin once; later DNS answers cannot expand its LAN grant.
    let granted: Vec<IpAddr> = lookup_host((configured.host.as_str(), configured.port))
        .await?
        .map(|address| address.ip())
        .collect();
    let mut current = url.to_string();
    for _ in 0..=MAX_REDIRECTS {
        let parsed = parse_url(&current)?;
        if configured.https && !parsed.https {
            return Err(HttpError::InvalidUrl("HTTPS downgrade is not allowed"));
        }
        let addresses: Vec<SocketAddr> = lookup_host((parsed.host.as_str(), parsed.port))
            .await?
            .collect();
        let same = configured.url.origin() == parsed.url.origin();
        if addresses.is_empty()
            || addresses
                .iter()
                .any(|address| !address_allowed(address.ip(), same, &granted))
        {
            return Err(HttpError::InvalidUrl("destination is not permitted"));
        }
        // Connect only to the checked addresses, with no second resolver lookup.
        let tcp = TcpStream::connect(addresses.as_slice()).await?;
        tcp.set_nodelay(true).ok();
        let host = if parsed.host.contains(':') {
            format!("[{}]", parsed.host)
        } else {
            parsed.host.clone()
        };
        let default_port = if parsed.https { 443 } else { 80 };
        let host_header = if parsed.port == default_port {
            host
        } else {
            format!("{host}:{}", parsed.port)
        };
        let response = if parsed.https {
            let server_name = ServerName::try_from(parsed.host.clone())
                .map_err(|_| HttpError::InvalidUrl("invalid server name"))?;
            let mut tls = tls_connector()
                .connect(server_name, tcp)
                .await
                .map_err(|_| HttpError::Tls("handshake failed".to_string()))?;
            exchange(&mut tls, &host_header, &parsed.target, max_bytes).await?
        } else {
            let mut plain = tcp;
            exchange(&mut plain, &host_header, &parsed.target, max_bytes).await?
        };
        match response.status {
            301 | 302 | 303 | 307 | 308 => {
                let location = response
                    .header("location")
                    .ok_or(HttpError::Malformed("redirect has no Location"))?;
                current = resolve_redirect(&parsed, location)?;
            }
            _ => return Ok(response),
        }
    }
    Err(HttpError::TooManyRedirects)
}

/// Tek bağlantı üzerinde istek/yanıt turu. TLS'siz akışlarla da
/// çalışabildiği için birim testleri `duplex` ile ağsız yapılır.
async fn exchange<S>(
    stream: &mut S,
    host_header: &str,
    target: &str,
    max_bytes: usize,
) -> Result<HttpResponse, HttpError>
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    if !target.starts_with('/')
        || host_header.is_empty()
        || host_header.bytes().any(|b| b <= 0x20 || b == 0x7f)
        || target.bytes().any(|b| b <= 0x20 || b == 0x7f)
    {
        return Err(HttpError::InvalidUrl("unsafe HTTP request fields"));
    }
    let request = format!(
        "GET {target} HTTP/1.1\r\nHost: {host_header}\r\nUser-Agent: {USER_AGENT}\r\n\
         Accept: */*\r\nAccept-Encoding: identity\r\nConnection: close\r\n\r\n"
    );
    stream.write_all(request.as_bytes()).await?;
    stream.flush().await?;

    let mut reader = BufReader::new(stream);
    let status_line = read_line(&mut reader, MAX_HEADER_BYTES).await?;
    let status = parse_status_line(&status_line)?;

    let mut headers = Vec::new();
    let mut header_bytes = status_line.len();
    loop {
        let line = read_line(&mut reader, MAX_HEADER_BYTES).await?;
        header_bytes += line.len();
        if header_bytes > MAX_HEADER_BYTES {
            return Err(HttpError::Malformed("header block too long"));
        }
        let trimmed = trim_line(&line);
        if trimmed.is_empty() {
            break;
        }
        if let Some((name, value)) = trimmed.split_once(':') {
            headers.push((name.trim().to_string(), value.trim().to_string()));
        }
    }

    let body = read_body(&mut reader, &headers, max_bytes).await?;
    Ok(HttpResponse {
        status,
        headers,
        body,
    })
}

fn parse_status_line(line: &[u8]) -> Result<u16, HttpError> {
    let text = String::from_utf8_lossy(line);
    let mut parts = text.split_whitespace();
    let version = parts.next().unwrap_or_default();
    if !version.starts_with("HTTP/") {
        return Err(HttpError::Malformed("status line does not start with HTTP"));
    }
    parts
        .next()
        .and_then(|code| code.parse().ok())
        .ok_or(HttpError::Malformed("could not read status code"))
}

/// `\n` ile biten satırı (sınır aşımına karşı korumalı) okur; EOF'ta eldeki
/// baytlar döner.
async fn read_line<S>(reader: &mut BufReader<&mut S>, cap: usize) -> Result<Vec<u8>, HttpError>
where
    S: AsyncRead + Unpin,
{
    let mut line = Vec::with_capacity(128);
    let mut byte = [0u8; 1];
    loop {
        if line.len() >= cap {
            return Err(HttpError::Malformed("line too long"));
        }
        let read = reader.read(&mut byte).await?;
        if read == 0 {
            return Ok(line);
        }
        line.push(byte[0]);
        if byte[0] == b'\n' {
            return Ok(line);
        }
    }
}

fn trim_line(line: &[u8]) -> &str {
    let end = line
        .iter()
        .rposition(|b| !matches!(b, b'\r' | b'\n'))
        .map(|idx| idx + 1)
        .unwrap_or(0);
    std::str::from_utf8(&line[..end]).unwrap_or("")
}

async fn read_body<S>(
    reader: &mut BufReader<&mut S>,
    headers: &[(String, String)],
    max_bytes: usize,
) -> Result<Vec<u8>, HttpError>
where
    S: AsyncRead + Unpin,
{
    let chunked = headers.iter().any(|(name, value)| {
        name.eq_ignore_ascii_case("transfer-encoding")
            && value.to_ascii_lowercase().contains("chunked")
    });
    if chunked {
        return read_chunked(reader, max_bytes).await;
    }

    if let Some((_, value)) = headers
        .iter()
        .find(|(name, _)| name.eq_ignore_ascii_case("content-length"))
    {
        let len: usize = value
            .trim()
            .parse()
            .map_err(|_| HttpError::Malformed("could not read Content-Length"))?;
        if len > max_bytes {
            return Err(HttpError::TooLarge { limit: max_bytes });
        }
        let mut body = vec![0u8; len];
        reader.read_exact(&mut body).await?;
        return Ok(body);
    }

    // Uzunluk yoksa `Connection: close` ile EOF'a kadar oku.
    let mut body = Vec::new();
    let mut chunk = [0u8; 16 * 1024];
    loop {
        let read = reader.read(&mut chunk).await?;
        if read == 0 {
            return Ok(body);
        }
        if body.len() + read > max_bytes {
            return Err(HttpError::TooLarge { limit: max_bytes });
        }
        body.extend_from_slice(&chunk[..read]);
    }
}

async fn read_chunked<S>(
    reader: &mut BufReader<&mut S>,
    max_bytes: usize,
) -> Result<Vec<u8>, HttpError>
where
    S: AsyncRead + Unpin,
{
    let mut body = Vec::new();
    loop {
        let size_line = read_line(reader, 1024).await?;
        let size_text = trim_line(&size_line);
        // "1a4;ext=..." biçiminde chunk uzantıları atılır.
        let size_hex = size_text.split(';').next().unwrap_or_default().trim();
        let size = usize::from_str_radix(size_hex, 16)
            .map_err(|_| HttpError::Malformed("bozuk chunk boyutu"))?;
        if size == 0 {
            // Trailer satırlarını boş satıra kadar atla.
            loop {
                let trailer = read_line(reader, MAX_HEADER_BYTES).await?;
                if trim_line(&trailer).is_empty() {
                    break;
                }
            }
            return Ok(body);
        }
        if size > max_bytes.saturating_sub(body.len()) {
            return Err(HttpError::TooLarge { limit: max_bytes });
        }
        let start = body.len();
        body.resize(start + size, 0);
        reader.read_exact(&mut body[start..]).await?;
        // Her chunk'ın sonunda CRLF bulunur.
        let mut crlf = [0u8; 2];
        reader.read_exact(&mut crlf).await?;
        if &crlf != b"\r\n" {
            return Err(HttpError::Malformed("chunk end is not CRLF"));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{duplex, AsyncWriteExt};

    /// Sahte sunucuya isteği okutup beklenen öneki doğrular, yanıtı basar.
    async fn serve_once(
        server: tokio::io::DuplexStream,
        expected_prefix: &'static str,
        response: &'static str,
    ) {
        let mut server = server;
        let mut request = vec![0u8; expected_prefix.len()];
        server.read_exact(&mut request).await.unwrap();
        assert_eq!(
            String::from_utf8_lossy(&request),
            expected_prefix,
            "client sent an unexpected request"
        );
        server.write_all(response.as_bytes()).await.unwrap();
        server.shutdown().await.unwrap();
    }

    #[test]
    fn url_ayristirma_temel_durumlar() {
        let parsed = parse_url("https://indexer.example/api?t=search&q=a%20b").unwrap();
        assert!(parsed.https);
        assert_eq!(parsed.host, "indexer.example");
        assert_eq!(parsed.port, 443);
        assert_eq!(parsed.target, "/api?t=search&q=a%20b");

        let parsed = parse_url("http://indexer.example:8080/api").unwrap();
        assert!(!parsed.https);
        assert_eq!(parsed.port, 8080);
        assert_eq!(parsed.target, "/api");

        let parsed = parse_url("https://indexer.example").unwrap();
        assert_eq!(parsed.target, "/");

        assert!(parse_url("https://user:TESTPASS123@indexer.example/api").is_err());
    }

    #[test]
    fn url_ayristirma_hatalari() {
        assert!(matches!(
            parse_url("ftp://x.example/"),
            Err(HttpError::InvalidUrl(_))
        ));
        assert!(matches!(
            parse_url("https:///api"),
            Err(HttpError::InvalidUrl(_))
        ));
        assert!(matches!(
            parse_url("https://x.example:abc/api"),
            Err(HttpError::InvalidUrl(_))
        ));
    }

    #[test]
    fn yonlendirme_cozumleme() {
        let base = parse_url("https://a.example/api?t=get&id=1").unwrap();
        assert_eq!(
            resolve_redirect(&base, "https://b.example/get/2").unwrap(),
            "https://b.example/get/2"
        );
        assert_eq!(
            resolve_redirect(&base, "/dl/2").unwrap(),
            "https://a.example/dl/2"
        );
        assert_eq!(
            resolve_redirect(&base, "nzb/3").unwrap(),
            "https://a.example/nzb/3"
        );

        let base = parse_url("http://a.example:8080/api?t=1").unwrap();
        assert_eq!(
            resolve_redirect(&base, "/get").unwrap(),
            "http://a.example:8080/get"
        );
    }

    #[test]
    fn review_url_validation_regressions() {
        for input in [
            "https://user:TESTPASS123@indexer.example/api",
            "https://indexer.example/api\r\nX-Injected: yes",
            "https://indexer.example\t/api",
            "https://indexer.example/\\evil.example/api",
        ] {
            assert!(parse_url(input).is_err(), "unsafe URL was accepted");
        }
        let parsed = parse_url("http://[::1]:8080/api?q=one#ignored").unwrap();
        assert_eq!(parsed.host, "::1");
        assert_eq!(parsed.port, 8080);
        assert_eq!(parsed.target, "/api?q=one");
        let parsed = parse_url("https://indexer.example?q=one").unwrap();
        assert_eq!(parsed.target, "/?q=one");
    }

    #[test]
    fn review_redirect_validation_regressions() {
        let base = parse_url("https://a.example/a/b?q=old").unwrap();
        assert!(resolve_redirect(&base, "http://a.example/plain").is_err());
        assert!(resolve_redirect(&base, "https://user:TESTPASS123@a.example/").is_err());
        assert!(resolve_redirect(&base, "/ok\r\nX-Injected: yes").is_err());
        assert_eq!(
            resolve_redirect(&base, "//b.example/new").unwrap(),
            "https://b.example/new"
        );
        assert_eq!(
            resolve_redirect(&base, "../new").unwrap(),
            "https://a.example/new"
        );
        assert_eq!(
            resolve_redirect(&base, "?q=new").unwrap(),
            "https://a.example/a/b?q=new"
        );
    }

    #[test]
    fn review_address_policy_checks_actual_ip_and_origin() {
        let granted = [
            "127.0.0.1".parse().unwrap(),
            "192.168.1.20".parse().unwrap(),
            "::1".parse().unwrap(),
        ];
        for address in [
            "127.0.0.1",
            "10.0.0.2",
            "192.168.1.20",
            "::1",
            "fc00::1",
            "::ffff:127.0.0.1",
        ] {
            assert!(!address_allowed(address.parse().unwrap(), false, &granted));
        }
        assert!(address_allowed(granted[0], true, &granted));
        assert!(address_allowed(granted[1], true, &granted));
        assert!(address_allowed(granted[2], true, &granted));
        // A changed DNS answer cannot expand an existing LAN grant.
        assert!(!address_allowed(
            "192.168.1.21".parse().unwrap(),
            true,
            &granted
        ));
        for address in [
            "169.254.169.254",
            "fe80::1",
            "0.0.0.0",
            "::",
            "224.0.0.1",
            "100.64.0.1",
        ] {
            let ip = address.parse().unwrap();
            assert!(!address_allowed(ip, true, &[ip]));
        }
        assert!(address_allowed("1.1.1.1".parse().unwrap(), false, &[]));
        assert!(address_allowed(
            "2606:4700:4700::1111".parse().unwrap(),
            false,
            &[]
        ));
        assert!(same_origin(
            "https://indexer.example/api",
            "https://INDEXER.example:443/get"
        ));
        assert!(!same_origin(
            "https://indexer.example/api",
            "http://indexer.example/get"
        ));
        assert!(!same_origin(
            "https://indexer.example/api",
            "https://other.example/get"
        ));
    }

    #[tokio::test]
    async fn review_cross_origin_loopback_redirect_never_connects() {
        let destination = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let target = destination.local_addr().unwrap();
        let source = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let origin = source.local_addr().unwrap();
        let task = tokio::spawn(async move {
            let (mut connection, _) = source.accept().await.unwrap();
            let mut request = [0; 1024];
            assert!(connection.read(&mut request).await.unwrap() > 0);
            let response = format!("HTTP/1.1 302 Found\r\nLocation: http://{target}/private\r\nContent-Length: 0\r\n\r\n");
            connection.write_all(response.as_bytes()).await.unwrap();
        });
        let result = http_get(&format!("http://{origin}/api"), 100, Duration::from_secs(2)).await;
        assert!(matches!(
            result,
            Err(HttpError::InvalidUrl("destination is not permitted"))
        ));
        assert!(
            tokio::time::timeout(Duration::from_millis(25), destination.accept())
                .await
                .is_err()
        );
        task.await.unwrap();
    }

    #[tokio::test]
    async fn review_request_fields_are_checked_before_write() {
        let (mut client, _) = duplex(512);
        assert!(exchange(&mut client, "safe.example\r\nX: yes", "/", 100)
            .await
            .is_err());
        assert!(exchange(&mut client, "safe.example", "/ok\r\nX: yes", 100)
            .await
            .is_err());
    }

    #[tokio::test]
    async fn content_length_ile_yanit() {
        let (mut client, server) = duplex(4096);
        let server_task = tokio::spawn(serve_once(
            server,
            "GET /api?t=search HTTP/1.1\r\n",
            "HTTP/1.1 200 OK\r\nContent-Length: 5\r\nX-Test: evet\r\n\r\nhello",
        ));
        let response = exchange(&mut client, "idx.example", "/api?t=search", 1024)
            .await
            .unwrap();
        assert_eq!(response.status, 200);
        assert_eq!(response.header("x-test"), Some("evet"));
        assert_eq!(response.body, b"hello");
        server_task.await.unwrap();
    }

    #[tokio::test]
    async fn chunked_govde_ve_trailer() {
        let (mut client, server) = duplex(4096);
        let server_task = tokio::spawn(serve_once(
            server,
            "GET /feed HTTP/1.1\r\n",
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n\
             5\r\nhello\r\n6;ext=x\r\n world\r\n0\r\nX-Trailer: y\r\n\r\n",
        ));
        let response = exchange(&mut client, "idx.example", "/feed", 1024)
            .await
            .unwrap();
        assert_eq!(response.body, b"hello world");
        server_task.await.unwrap();
    }

    #[tokio::test]
    async fn uzunluk_yoksa_eofa_kadar_okunur() {
        let (mut client, server) = duplex(4096);
        let server_task = tokio::spawn(serve_once(
            server,
            "GET /x HTTP/1.1\r\n",
            "HTTP/1.1 200 OK\r\n\r\nkapanana dek govde",
        ));
        let response = exchange(&mut client, "idx.example", "/x", 1024)
            .await
            .unwrap();
        assert_eq!(response.body, "kapanana dek govde".as_bytes());
        server_task.await.unwrap();
    }

    #[tokio::test]
    async fn boyut_siniri_content_length_ile() {
        let (mut client, server) = duplex(4096);
        let server_task = tokio::spawn(serve_once(
            server,
            "GET /big HTTP/1.1\r\n",
            "HTTP/1.1 200 OK\r\nContent-Length: 999\r\n\r\n",
        ));
        let result = exchange(&mut client, "idx.example", "/big", 100).await;
        assert!(matches!(result, Err(HttpError::TooLarge { limit: 100 })));
        server_task.await.unwrap();
    }

    #[tokio::test]
    async fn bozuk_durum_satiri_reddedilir() {
        let (mut client, server) = duplex(4096);
        let server_task = tokio::spawn(serve_once(
            server,
            "GET /x HTTP/1.1\r\n",
            "MERHABA bu bir http yaniti degil\r\n\r\n",
        ));
        let result = exchange(&mut client, "idx.example", "/x", 100).await;
        assert!(matches!(result, Err(HttpError::Malformed(_))));
        server_task.await.unwrap();
    }

    /// Yerel geri çevrim üzerinde 301 → 200 zinciri; dış ağ gerektirmez.
    #[tokio::test]
    async fn yonlendirme_zinciri_yerel_sunucuda() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let server = tokio::spawn(async move {
            // 1. istek: 301 döndür.
            let (mut conn, _) = listener.accept().await.unwrap();
            let mut buf = [0u8; 512];
            let _ = conn.read(&mut buf).await.unwrap();
            conn.write_all(b"HTTP/1.1 301 Moved\r\nLocation: /son\r\nContent-Length: 0\r\n\r\n")
                .await
                .unwrap();
            // 2. istek: 200 döndür.
            let (mut conn, _) = listener.accept().await.unwrap();
            let _ = conn.read(&mut buf).await.unwrap();
            conn.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
                .await
                .unwrap();
        });

        let url = format!("http://127.0.0.1:{port}/basla");
        let response = http_get(&url, 1024, Duration::from_secs(5)).await.unwrap();
        assert_eq!(response.status, 200);
        assert_eq!(response.body, b"ok");
        server.await.unwrap();
    }

    #[tokio::test]
    async fn sonsuz_yonlendirme_siniri() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let server = tokio::spawn(async move {
            loop {
                let Ok((mut conn, _)) = listener.accept().await else {
                    break;
                };
                tokio::spawn(async move {
                    let mut buf = [0u8; 512];
                    let _ = conn.read(&mut buf).await.unwrap();
                    let _ = conn
                        .write_all(
                            b"HTTP/1.1 302 Found\r\nLocation: /tekrar\r\nContent-Length: 0\r\n\r\n",
                        )
                        .await;
                });
            }
        });

        let url = format!("http://127.0.0.1:{port}/basla");
        let result = http_get(&url, 1024, Duration::from_secs(10)).await;
        assert!(matches!(result, Err(HttpError::TooManyRedirects)));
        server.abort();
    }
}
