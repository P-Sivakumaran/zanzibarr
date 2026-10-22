import 'dart:async';
import 'dart:convert';
import 'metadata_links.dart';
import 'title_trailer.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Optional credentials stay in OS secure storage; requests and errors are
/// never logged. Automatic enrichment uses configured metadata access.
class MetadataSettingsStore {
  MetadataSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'metadata.omdb.apiKey';

  Future<String> load() async => await _storage.read(key: _key) ?? '';
  Future<void> save(String key) async {
    if (key.trim().isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: key.trim());
    }
  }
}

String? normalizeImdbId(String value) {
  final match = RegExp(
    r'^(?:tt)?(\d{7,10})$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  return match == null ? null : 'tt${match[1]}';
}

bool isValidMetadataApiKey(String value) =>
    RegExp(r'^[a-zA-Z0-9]{1,128}$').hasMatch(value.trim());

/// Accept exact, bounded positive counts; never expand rounded "1.2M" labels.
int? parseRatingCount(Object? raw) {
  if (raw is int) return raw > 0 && raw <= 10000000000 ? raw : null;
  if (raw is! String ||
      raw.length > 20 ||
      !RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$').hasMatch(raw)) {
    return null;
  }
  final count = int.tryParse(raw.replaceAll(',', ''));
  return count != null && count > 0 && count <= 10000000000 ? count : null;
}

class MediaTitle {
  const MediaTitle({
    required this.imdbId,
    required this.title,
    required this.year,
    required this.kind,
    this.trailer,
    this.plot = '',
    this.genre = '',
    this.runtime = '',
    this.ratings = const {},
    this.ratingCounts = const {},
    this.poster = '',
    this.certification = '',
    this.originalLanguage = '',
    this.actors = '',
    this.director = '',
    this.writer = '',
    this.awards = '',
    this.country = '',
    this.released = '',
    this.cast = const [],
    this.topics = const [],
    this.filmingLocations = const [],
    this.narrativeLocations = const [],
    this.enrichmentSources = const [],
    this.ratingProviders = const {},
    this.locationSource = '',
    this.totalSeasons,
    this.fetchedAt,
    this.provider = 'OMDb',
  });
  final String imdbId;
  final String title;
  final String year;

  /// OMDb uses movie / series. Episode lookups are deliberately not guessed
  /// into series identities.
  final String kind;
  final TitleTrailer? trailer;
  final String plot;
  final String genre;
  final String runtime;
  final Map<String, String> ratings;

  /// IMDb counts are votes; Rotten Tomatoes/Metacritic counts are critic reviews.
  final Map<String, int> ratingCounts;
  final String poster;
  final String certification;
  final String originalLanguage;
  final String actors;
  final String director, writer, awards, country, released;
  final List<CastMember> cast;
  final List<String> topics, filmingLocations, narrativeLocations;
  final List<String> enrichmentSources;
  final Map<String, String> ratingProviders;
  final String locationSource;
  final int? totalSeasons;
  final DateTime? fetchedAt;
  final String provider;

  Map<String, Object?> toJson() => {
    'imdbID': imdbId,
    'Title': title,
    'Year': year,
    'Type': kind,
    'Plot': plot,
    if (trailer != null) 'trailer': trailer!.toJson(),
    'Genre': genre,
    'Runtime': runtime,
    'Poster': artworkUri(poster)?.toString() ?? '',
    'Rated': certification,
    'Language': originalLanguage,
    'Actors': actors,
    'Director': director,
    'Writer': writer,
    'Awards': awards,
    'Country': country,
    'Released': released,
    'cast': [for (final person in cast) person.toJson()],
    'topics': topics,
    'filmingLocations': filmingLocations,
    'narrativeLocations': narrativeLocations,
    'enrichmentSources': enrichmentSources,
    'ratingProviders': ratingProviders,
    'locationSource': locationSource,
    'totalSeasons': totalSeasons?.toString(),
    'fetchedAt': fetchedAt?.toIso8601String(),
    'metadataProvider': provider,
    'Ratings': [
      for (final r in ratings.entries)
        {
          'Source': r.key == 'IMDb' ? 'Internet Movie Database' : r.key,
          'Value': r.value,
          if (ratingCounts[r.key] != null) 'Count': ratingCounts[r.key],
        },
    ],
  };

  factory MediaTitle.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      return value is String && value != 'N/A' ? value : '';
    }

    final id = normalizeImdbId(field('imdbID'));
    final kind = field('Type');
    if (id == null ||
        field('Title').isEmpty ||
        !['movie', 'series'].contains(kind)) {
      throw const FormatException('Invalid metadata title');
    }
    final ratings = <String, String>{};
    final counts = <String, int>{};
    for (final row
        in (json['Ratings'] is List ? json['Ratings'] as List : const [])) {
      if (row is! Map) continue;
      final source = row['Source'];
      final value = row['Value'];
      if (source is String &&
          value is String &&
          value.isNotEmpty &&
          value != 'N/A') {
        if ([
          'Internet Movie Database',
          'Rotten Tomatoes',
          'Metacritic',
        ].contains(source)) {
          ratings[source == 'Internet Movie Database' ? 'IMDb' : source] =
              value;
          final count = parseRatingCount(row['Count']);
          if (count != null) {
            counts[source == 'Internet Movie Database' ? 'IMDb' : source] =
                count;
          }
        }
      }
    }
    if (!ratings.containsKey('IMDb') && field('imdbRating').isNotEmpty) {
      ratings['IMDb'] = '${field('imdbRating')}/10';
    }
    if (!ratings.containsKey('Metacritic') && field('Metascore').isNotEmpty) {
      ratings['Metacritic'] = '${field('Metascore')}/100';
    }
    for (final entry in {'IMDb': json['imdbVotes']}.entries) {
      final count = parseRatingCount(entry.value);
      if (count != null && ratings.containsKey(entry.key)) {
        counts.putIfAbsent(entry.key, () => count);
      }
    }
    return MediaTitle(
      imdbId: id,
      title: field('Title'),
      year: field('Year'),
      kind: kind,
      plot: field('Plot'),
      trailer: TitleTrailer.fromJson(json['trailer']),
      genre: field('Genre'),
      runtime: field('Runtime'),
      ratings: Map.unmodifiable(ratings),
      ratingCounts: Map.unmodifiable(counts),
      poster: artworkUri(field('Poster'))?.toString() ?? '',
      certification: field('Rated'),
      originalLanguage: field('Language'),
      actors: field('Actors'),
      director: field('Director'),
      writer: field('Writer'),
      awards: field('Awards'),
      country: field('Country'),
      released: field('Released'),
      cast: [
        for (final row
            in (json['cast'] is List ? json['cast'] as List : const []).take(
              40,
            ))
          if (row is Map &&
              row['name'] is String &&
              (row['name'] as String).isNotEmpty)
            CastMember.fromJson(Map<String, dynamic>.from(row)),
      ],
      topics: metadataStrings(json['topics']),
      filmingLocations: metadataStrings(json['filmingLocations']),
      narrativeLocations: metadataStrings(json['narrativeLocations']),
      enrichmentSources: metadataStrings(json['enrichmentSources']),
      ratingProviders: {
        if (json['ratingProviders'] is Map)
          for (final e in (json['ratingProviders'] as Map).entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
      },
      locationSource:
          RegExp(
            r'^https://www.wikidata.org/wiki/Q[0-9]+$',
          ).hasMatch(field('locationSource'))
          ? field('locationSource')
          : '',
      totalSeasons: int.tryParse(field('totalSeasons'))?.clamp(0, 100),
      fetchedAt: DateTime.tryParse(field('fetchedAt')),
      provider: field('metadataProvider').isEmpty
          ? 'OMDb'
          : field('metadataProvider'),
    );
  }
}

List<String> metadataStrings(Object? value) => value is List
    ? value
          .whereType<String>()
          .where((s) => s.isNotEmpty && s.length <= 300)
          .take(40)
          .toList()
    : const [];

class CastMember {
  const CastMember({required this.name, this.character = '', this.photo = ''});
  final String name, character, photo;
  Map<String, Object?> toJson() => {
    'name': name,
    'character': character,
    'photo': photo,
  };
  factory CastMember.fromJson(Map<String, dynamic> row) => CastMember(
    name: (row['name'] as String).substring(
      0,
      (row['name'] as String).length.clamp(0, 200),
    ),
    character: row['character'] is String
        ? (row['character'] as String).substring(
            0,
            (row['character'] as String).length.clamp(0, 300),
          )
        : '',
    photo:
        artworkUri(
          row['photo'] is String ? row['photo'] as String : '',
        )?.toString() ??
        '',
  );
}

class MetadataPage {
  const MetadataPage(this.titles, {this.hasMore = false});
  final List<MediaTitle> titles;
  final bool hasMore;
}

/// Static errors prevent server bodies and key-bearing URLs from reaching UI.
class MetadataException implements Exception {
  const MetadataException(this.code);
  final String code;
  @override
  String toString() => 'Metadata unavailable ($code)';
}

class MetadataService {
  MetadataService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _now;
  final _cache = <String, ({DateTime expires, Map<String, dynamic> data})>{};
  final _pending = <String, Future<Map<String, dynamic>>>{};
  String _credential = '';
  bool _closed = false;

  /// Always checks the draft against OMDb, bypassing the metadata cache.
  /// Testing does not persist credentials or change the active lookup key.
  Future<void> testApiKey(String apiKey) async {
    if (!isValidMetadataApiKey(apiKey)) throw const MetadataException('key');
    if (_closed) throw const MetadataException('closed');
    final data = await _fetch(apiKey.trim(), {'i': 'tt0133093'});
    try {
      final media = MediaTitle.fromJson(data);
      if (media.imdbId != 'tt0133093') {
        throw const MetadataException('response');
      }
    } on FormatException {
      throw const MetadataException('response');
    }
  }

  void clearCache() {
    _cache.clear();
    _pending.clear();
    _credential = '';
  }

  void close() {
    _closed = true;
    _client.close();
    _cache.clear();
    _pending.clear();
    _credential = '';
  }

  Future<Map<String, dynamic>> _request(
    String apiKey,
    Map<String, String> params,
  ) async {
    if (apiKey.trim().isEmpty) throw const MetadataException('key');
    if (_closed) throw const MetadataException('closed');
    if (_credential != apiKey) {
      _credential = apiKey;
      _cache.clear();
      _pending.clear();
    }
    final cacheKey = jsonEncode(params);
    final cached = _cache[cacheKey];
    if (cached != null && cached.expires.isAfter(_now())) return cached.data;
    final existing = _pending[cacheKey];
    if (existing != null) return existing;
    final future = _fetch(apiKey, params).then(
      (data) => <String, dynamic>{
        ...data,
        'fetchedAt': _now().toIso8601String(),
      },
    );
    _pending[cacheKey] = future;
    try {
      final data = await future;
      if (!_closed && _credential == apiKey) {
        if (_cache.length >= 100) _cache.remove(_cache.keys.first);
        _cache[cacheKey] = (
          expires: _now().add(const Duration(hours: 6)),
          data: data,
        );
      }
      return data;
    } finally {
      if (identical(_pending[cacheKey], future)) _pending.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _fetch(
    String apiKey,
    Map<String, String> params,
  ) async {
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 15), () => abort.complete());
    try {
      final request = http.AbortableRequest(
        'GET',
        Uri.https('www.omdbapi.com', '/', {
          'apikey': apiKey,
          'r': 'json',
          ...params,
        }),
        abortTrigger: abort.future,
      )..followRedirects = false;
      // Bound the complete request, including streamed response bodies.
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          throw const MetadataException('network');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw const MetadataException('response');
          }
          bytes.addAll(chunk);
        }
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (data['Response'] == 'False') {
          // Interpret known conditions, but never expose the remote text.
          final error = (data['Error'] as String? ?? '').toLowerCase();
          if (error.contains('not found') || error.contains('no results')) {
            return {'Search': <dynamic>[]};
          }
          if (error.contains('limit')) throw const MetadataException('limit');
          if (error.contains('key')) throw const MetadataException('key');
          throw const MetadataException('response');
        }
        return data;
      })().timeout(const Duration(seconds: 15));
    } on MetadataException {
      rethrow;
    } catch (_) {
      throw const MetadataException('network');
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<MetadataPage> search(
    String apiKey,
    String query, {
    String? kind,
    int page = 1,
    int? year,
  }) async {
    if (query.trim().isEmpty) return const MetadataPage([]);
    final id = normalizeImdbId(query);
    if (id != null) {
      final title = await details(apiKey, id);
      return MetadataPage([?title]);
    }
    final data = await _request(apiKey, {
      's': query.trim(),
      'page': '$page',
      'type': ?kind,
      'y': ?year?.toString(),
    });
    final titles = <MediaTitle>[];
    if (data['Search'] is! List) throw const MetadataException('response');
    for (final row in data['Search'] as List) {
      if (row is! Map<String, dynamic>) continue;
      try {
        titles.add(MediaTitle.fromJson(row));
      } on FormatException {
        continue;
      }
    }
    final total = int.tryParse('${data['totalResults']}');
    return MetadataPage(
      titles,
      hasMore:
          titles.isNotEmpty && page < 100 && total != null && page * 10 < total,
    );
  }

  /// Only the selected season is fetched; catalog membership does not establish
  /// release availability. No next-integer episode guesses are made here.
  Future<List<MediaEpisode>> season(
    String apiKey,
    String id,
    int season,
  ) async {
    final normalized = normalizeImdbId(id);
    if (normalized == null || season < 0 || season > 100) {
      throw const MetadataException('id');
    }
    final data = await _request(apiKey, {'i': normalized, 'Season': '$season'});
    return parseSeason(data, season);
  }

  Future<MediaTitle?> details(String apiKey, String id) async {
    final normalized = normalizeImdbId(id);
    if (normalized == null) throw const MetadataException('id');
    final data = await _request(apiKey, {'i': normalized, 'plot': 'full'});
    if (!data.containsKey('imdbID')) return null;
    try {
      final title = MediaTitle.fromJson(data);
      if (title.imdbId != normalized) throw const MetadataException('response');
      return title;
    } on FormatException {
      throw const MetadataException('response');
    }
  }
}

class MediaEpisode {
  const MediaEpisode({
    required this.number,
    required this.title,
    this.aired,
    this.still = '',
    this.overview = '',
    this.runtimeMinutes,
    this.imdbId,
  });
  final int number;
  final String title;
  final DateTime? aired;
  final String still, overview;
  final int? runtimeMinutes;
  final String? imdbId;
  bool isFuture(DateTime now) => aired != null && aired!.isAfter(now);
}

List<MediaEpisode> parseSeason(Map<String, dynamic> data, int season) {
  if (int.tryParse('${data['Season']}') != season ||
      data['Episodes'] is! List ||
      (data['Episodes'] as List).length > 500) {
    throw const MetadataException('response');
  }
  final seen = <int>{};
  final result = <MediaEpisode>[];
  for (final row in data['Episodes'] as List) {
    if (row is! Map) continue;
    final number = int.tryParse('${row['Episode']}');
    final title = row['Title'];
    if (number == null ||
        number < 0 ||
        number > 9999 ||
        title is! String ||
        title.isEmpty ||
        !seen.add(number)) {
      continue;
    }
    result.add(
      MediaEpisode(
        number: number,
        title: title,
        aired: DateTime.tryParse('${row['Released']}'),
        imdbId: row['imdbID'] is String ? normalizeImdbId(row['imdbID']) : null,
      ),
    );
  }
  result.sort((a, b) => a.number.compareTo(b.number));
  return result;
}
