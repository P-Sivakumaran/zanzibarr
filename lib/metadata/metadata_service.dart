import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Optional credentials stay in OS secure storage; requests and errors are
/// never logged. Metadata is requested only by an explicit user action.
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

class MediaTitle {
  const MediaTitle({
    required this.imdbId,
    required this.title,
    required this.year,
    required this.kind,
    this.plot = '',
    this.genre = '',
    this.runtime = '',
    this.ratings = const {},
  });
  final String imdbId;
  final String title;
  final String year;

  /// OMDb uses movie / series. Episode lookups are deliberately not guessed
  /// into series identities.
  final String kind;
  final String plot;
  final String genre;
  final String runtime;
  final Map<String, String> ratings;

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
        }
      }
    }
    if (!ratings.containsKey('IMDb') && field('imdbRating').isNotEmpty) {
      ratings['IMDb'] = '${field('imdbRating')}/10';
    }
    if (!ratings.containsKey('Metacritic') && field('Metascore').isNotEmpty) {
      ratings['Metacritic'] = '${field('Metascore')}/100';
    }
    return MediaTitle(
      imdbId: id,
      title: field('Title'),
      year: field('Year'),
      kind: kind,
      plot: field('Plot'),
      genre: field('Genre'),
      runtime: field('Runtime'),
      ratings: Map.unmodifiable(ratings),
    );
  }
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
    final future = _fetch(apiKey, params);
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

  Future<MediaTitle?> details(String apiKey, String id) async {
    final normalized = normalizeImdbId(id);
    if (normalized == null) throw const MetadataException('id');
    final data = await _request(apiKey, {'i': normalized, 'plot': 'short'});
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
