/// Public image CDNs only. No credentials, arbitrary plugin hosts, redirects,
/// private-network URLs, originals, or unbounded image decodes.
Uri? artworkUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment ||
      !{
        'm.media-amazon.com',
        'ia.media-imdb.com',
        'image.tmdb.org',
      }.contains(uri.host)) {
    return null;
  }
  return uri;
}
