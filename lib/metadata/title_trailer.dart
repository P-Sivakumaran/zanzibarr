/// Provider-selected YouTube trailers only. AI output never supplies these IDs.
class TitleTrailer {
  const TitleTrailer({
    required this.key,
    required this.name,
    this.teaser = false,
  });
  final String key, name;
  final bool teaser;
  static bool validKey(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value);
  Map<String, Object?> toJson() => {'key': key, 'name': name, 'teaser': teaser};
  static TitleTrailer? fromJson(Object? raw) {
    if (raw is! Map || raw['key'] is! String || !validKey(raw['key'])) {
      return null;
    }
    final name = raw['name'];
    return TitleTrailer(
      key: raw['key'],
      name: name is String && name.length <= 160 ? name : 'Official trailer',
      teaser: raw['teaser'] == true,
    );
  }

  Uri get watchUri => Uri.https('www.youtube.com', '/watch', {'v': key});
  Uri get embedUri => Uri.https('www.youtube-nocookie.com', '/embed/$key', {
    'playsinline': '1',
    'autoplay': '0',
    'rel': '0',
  });
}

TitleTrailer? selectTitleTrailer(Object? raw) {
  if (raw is! Map || raw['results'] is! List) return null;
  final rows = (raw['results'] as List)
      .take(100)
      .whereType<Map>()
      .where(
        (row) =>
            row['site'] == 'YouTube' &&
            row['official'] == true &&
            ['Trailer', 'Teaser'].contains(row['type']) &&
            row['key'] is String &&
            TitleTrailer.validKey(row['key']),
      );
  // Prefer trailers over teasers, and English where the catalog supplies it.
  final sorted = rows.toList()
    ..sort((a, b) {
      int rank(Map row) =>
          (row['type'] == 'Trailer' ? 0 : 2) +
          (row['iso_639_1'] == 'en' ? 0 : 1);
      return rank(a).compareTo(rank(b));
    });
  if (sorted.isEmpty) return null;
  final first = sorted.first;
  return TitleTrailer.fromJson({
    'key': first['key'],
    'name': first['name'],
    'teaser': first['type'] == 'Teaser',
  });
}
