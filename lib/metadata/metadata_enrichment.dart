import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../player/media_preferences.dart';
import '../integrations/integration_settings.dart';
import '../integrations/metadata_plugin.dart';
import 'metadata_service.dart';
import 'title_trailer.dart';

class EnrichmentSettings {
  const EnrichmentSettings({
    this.tmdbToken = '',
    this.locations = false,
    this.reviewConnectionId = '',
  });
  final String tmdbToken, reviewConnectionId;
  final bool locations;
  Map<String, Object?> toJson() => {
    'tmdbToken': tmdbToken,
    'locations': locations,
    'reviewConnectionId': reviewConnectionId,
  };
}

class EnrichmentSettingsStore {
  EnrichmentSettingsStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage _storage;
  Future<EnrichmentSettings> load() async {
    final raw = await _storage.read('metadata.enrichment.settings.v1');
    if (raw == null) return const EnrichmentSettings();
    if (raw.length > 4096) throw const MetadataException('settings');
    final data = jsonDecode(raw) as Map;
    return EnrichmentSettings(
      tmdbToken: data['tmdbToken'] as String? ?? '',
      locations: data['locations'] == true,
      reviewConnectionId: data['reviewConnectionId'] as String? ?? '',
    );
  }

  Future<void> save(EnrichmentSettings value) {
    if (value.tmdbToken.length > 2048 ||
        !RegExp(r'^[A-Za-z0-9._-]*$').hasMatch(value.tmdbToken)) {
      throw const MetadataException('token');
    }
    return _storage.write(
      'metadata.enrichment.settings.v1',
      jsonEncode(value.toJson()),
    );
  }
}

/// Lazy enrichment of an already identified title. Public response snapshots and
/// empty results persist; credentials only live in the separate secure settings.
class MetadataEnrichment {
  MetadataEnrichment({
    http.Client? client,
    PlayerPreferenceStorage? storage,
    EnrichmentSettingsStore? settings,
    IntegrationStore? integrations,
    DateTime Function()? now,
    MetadataService Function(McpConnection)? reviewFactory,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? FlutterSecurePlayerPreferenceStorage(),
       _settings = settings ?? EnrichmentSettingsStore(),
       _integrations = integrations ?? IntegrationStore(),
       _now = now ?? DateTime.now,
       _reviewFactory = reviewFactory ?? McpMetadataService.new;
  final MetadataService Function(McpConnection) _reviewFactory;
  final _reviewServices = <MetadataService>{};
  final http.Client _client;
  final PlayerPreferenceStorage _storage;
  final EnrichmentSettingsStore _settings;
  final IntegrationStore _integrations;
  final DateTime Function() _now;
  final _cache = <String, dynamic>{};
  final _pending = <String, Future<Map<String, dynamic>>>{};
  Future<void>? _loaded;
  Future<void> _writes = Future.value();
  bool _closed = false;
  String? status;
  bool trailersConfigured = false;
  final _settingsWaiters = <Completer<EnrichmentSettings>, Timer>{};
  Future<EnrichmentSettings> _readSettings() {
    if (_closed || _settingsWaiters.length >= 4) {
      return Future.error(const MetadataException('settings'));
    }
    final result = Completer<EnrichmentSettings>();
    final timer = Timer(const Duration(seconds: 3), () {
      _settingsWaiters.remove(result);
      if (!result.isCompleted) {
        result.completeError(const MetadataException('settings'));
      }
    });
    _settingsWaiters[result] = timer;
    _settings.load().then(
      (value) {
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) {
          result.completeError(const MetadataException('settings'));
        }
      },
    );
    return result.future.whenComplete(() {
      _settingsWaiters.remove(result)?.cancel();
      timer.cancel();
    });
  }

  void close() {
    _closed = true;
    for (final waiter in _settingsWaiters.entries) {
      waiter.value.cancel();
      if (!waiter.key.isCompleted) {
        waiter.key.completeError(const MetadataException('settings'));
      }
    }
    _settingsWaiters.clear();
    _client.close();
    for (final service in _reviewServices) {
      service.close();
    }
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read('metadata.enrichment.cache.v1');
      if (raw == null || raw.length > 4 * 1024 * 1024) return;
      final data = jsonDecode(raw);
      if (data is Map && data.length <= 100) {
        _cache.addAll(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      /* A damaged public cache is dispensable, unlike chosen IDs. */
    }
  }

  Future<Map<String, dynamic>> _cached(
    String key,
    Duration ttl,
    Future<Map<String, dynamic>> Function() fetch,
  ) async {
    await (_loaded ??= _load());
    if (_closed) return {};
    final id = sha256.convert(utf8.encode(key)).toString();
    final row = _cache[id];
    if (row is Map &&
        row['expires'] is int &&
        row['expires'] > _now().millisecondsSinceEpoch &&
        row['data'] is Map) {
      return Map<String, dynamic>.from(row['data']);
    }
    final pending = _pending[id];
    if (pending != null) return pending;
    // Lazy detail pages need few requests; reject excess rather than queueing
    // unbounded work. Errors get a short retry window; absent fields use ttl.
    if (_pending.length >= 2) return {};
    final future = () async {
      Map<String, dynamic> data;
      var expiry = ttl;
      try {
        data = await fetch();
      } on _EnrichmentBackoff catch (error) {
        data = {};
        expiry = error.delay;
        status = 'This metadata provider is busy. Its retry time is cached.';
      } catch (_) {
        data = {};
        expiry = const Duration(minutes: 5);
        status = 'Some additional details are temporarily unavailable.';
      }
      if (_closed) return <String, dynamic>{};
      _cache.remove(id);
      while (_cache.length >= 100) {
        _cache.remove(_cache.keys.first);
      }
      _cache[id] = {
        'expires': _now().add(expiry).millisecondsSinceEpoch,
        'data': data,
      };
      _writes = _writes
          .then((_) async {
            var encoded = jsonEncode(_cache);
            while (encoded.length > 4 * 1024 * 1024 && _cache.length > 1) {
              _cache.remove(_cache.keys.first);
              encoded = jsonEncode(_cache);
            }
            if (!_closed && encoded.length <= 4 * 1024 * 1024) {
              await _storage.write('metadata.enrichment.cache.v1', encoded);
            }
          })
          .catchError((Object _) {
            status = 'Additional details could not be cached on this device.';
          });
      await _writes;
      return data;
    }();
    _pending[id] = future;
    try {
      return await future;
    } finally {
      _pending.remove(id);
    }
  }

  Future<Map<String, dynamic>> _get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    if (_closed) return {};
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 12), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      return await (() async {
        final request = http.AbortableRequest(
          'GET',
          uri,
          abortTrigger: abort.future,
        )..followRedirects = false;
        request.headers.addAll({
          'Accept': 'application/json',
          'User-Agent': 'Zanzibarr/1.22 metadata',
          ...headers,
        });
        final response = await _client.send(request);
        if (response.statusCode == 429 || response.statusCode == 503) {
          final raw = response.headers['retry-after'] ?? '';
          var seconds = int.tryParse(raw);
          if (seconds == null) {
            try {
              seconds = HttpDate.parse(raw).difference(_now()).inSeconds;
            } catch (_) {}
          }
          throw _EnrichmentBackoff(
            Duration(seconds: (seconds ?? 300).clamp(300, 86400)),
          );
        }
        if (response.statusCode == 404) return <String, dynamic>{};
        if (response.statusCode != 200) {
          throw const MetadataException('enrichment');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            throw const MetadataException('response');
          }
          bytes.addAll(chunk);
        }
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      })().timeout(const Duration(seconds: 12));
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<MediaTitle> enrich(MediaTitle title) async {
    status = null;
    EnrichmentSettings config;
    try {
      config = await _readSettings();
    } catch (_) {
      status = 'Additional metadata settings could not be loaded.';
      return title;
    }
    if (_closed) return title;
    trailersConfigured = config.tmdbToken.isNotEmpty;
    var data = title.toJson();
    final sources = {...title.enrichmentSources};
    if (config.tmdbToken.isNotEmpty) {
      final patch = await _cached(
        'tmdb-v2:${title.kind}:${title.imdbId}',
        const Duration(days: 7),
        () => _tmdb(title, config.tmdbToken),
      );
      if (patch.isNotEmpty) {
        data.addAll(patch);
        sources.add('TMDB');
      }
    }
    if (config.locations && !_closed) {
      final patch = await _cached(
        'wikidata:${title.imdbId}',
        const Duration(days: 7),
        () => _locations(title),
      );
      if (patch.isNotEmpty) {
        data.addAll(patch);
        sources.add('Wikidata');
      }
    }
    if (config.reviewConnectionId.isNotEmpty && !_closed) {
      try {
        final connections = (await _integrations.load()).connections;
        final connection = connections
            .where((c) => c.metadata && c.id == config.reviewConnectionId)
            .firstOrNull;
        if (connection != null) {
          final patch = await _cached(
            'reviews:${connection.id}:${connection.url}:${title.kind}:${title.imdbId}',
            const Duration(hours: 24),
            () async {
              final service = _reviewFactory(connection);
              _reviewServices.add(service);
              try {
                final result = await service.details('', title.imdbId);
                if (result?.imdbId != title.imdbId ||
                    result?.kind != title.kind) {
                  throw const MetadataException('identity');
                }
                return result!.toJson();
              } finally {
                _reviewServices.remove(service);
                service.close();
              }
            },
          );
          final incoming = patch.isEmpty ? null : MediaTitle.fromJson(patch);
          final ratings = {...title.ratings};
          final counts = {...title.ratingCounts};
          final providers = {...title.ratingProviders};
          if (incoming != null) {
            for (final e in incoming.ratings.entries) {
              final count = incoming.ratingCounts[e.key];
              if (count != null && _validRating(e.key, e.value)) {
                // Replace the complete observation, never attach a new count
                // to a potentially older score from another provider.
                ratings[e.key] = e.value;
                counts[e.key] = count;
                providers[e.key] = connection.name;
              }
            }
            data['Ratings'] = [
              for (final e in ratings.entries)
                {
                  'Source': e.key == 'IMDb' ? 'Internet Movie Database' : e.key,
                  'Value': e.value,
                  if (counts[e.key] != null) 'Count': counts[e.key],
                },
            ];
            data['ratingProviders'] = providers;
          }
        } else {
          status =
              'The selected review provider is no longer available. Choose one in Settings.';
        }
      } catch (_) {
        status = 'Additional review data is temporarily unavailable.';
      }
    }
    data['enrichmentSources'] = sources.toList();
    return MediaTitle.fromJson(Map<String, dynamic>.from(data));
  }

  static bool _validRating(String source, String raw) {
    final match = RegExp(
      source == 'IMDb'
          ? r'^(\d+(?:\.\d+)?)/10$'
          : source == 'Rotten Tomatoes'
          ? r'^(\d+(?:\.\d+)?)(?:%|/100)$'
          : r'^(\d+(?:\.\d+)?)/100$',
    ).firstMatch(raw);
    final value = double.tryParse(match?.group(1) ?? '');
    return value != null &&
        value >= 0 &&
        value <= (source == 'IMDb' ? 10 : 100);
  }

  /// One lazy request per selected season, reusing verified series identity and
  /// the bounded persistent cache. No title-search guess or per-episode fan-out.
  Future<List<MediaEpisode>> seasonEpisodes(
    MediaTitle title,
    int season,
    List<MediaEpisode> base,
  ) async {
    if (_closed ||
        title.kind != 'series' ||
        season < 0 ||
        season > 100 ||
        normalizeImdbId(title.imdbId) == null) {
      return base;
    }
    EnrichmentSettings config;
    try {
      config = await _readSettings();
    } catch (_) {
      return base;
    }
    if (config.tmdbToken.isEmpty) return base;
    final patch = await _cached(
      'tmdb-season-v1:${title.imdbId}:$season',
      const Duration(hours: 24),
      () async {
        final mappingKey = 'tmdb-id:series:${title.imdbId}';
        final mapping = _cache[mappingKey];
        if (mapping is! Map ||
            mapping['expires'] is! int ||
            mapping['expires'] <= _now().millisecondsSinceEpoch) {
          await _tmdb(title, config.tmdbToken);
        }
        final verified = _cache[mappingKey];
        if (verified is! Map || verified['id'] is! int) return {};
        final id = verified['id'] as int;
        final data = await _get(
          Uri.https('api.themoviedb.org', '/3/tv/$id/season/$season', {
            'language': 'en-US',
          }),
          headers: {'Authorization': 'Bearer ${config.tmdbToken}'},
        );
        if (data['season_number'] != season ||
            data['episodes'] is! List ||
            (data['episodes'] as List).length > 500) {
          throw const MetadataException('response');
        }
        return {
          'episodes': [
            for (final row in data['episodes'])
              if (row is Map &&
                  row['season_number'] == season &&
                  (row['show_id'] == null || row['show_id'] == id) &&
                  row['episode_number'] is int &&
                  row['episode_number'] >= 0 &&
                  row['episode_number'] <= 9999 &&
                  row['name'] is String &&
                  (row['name'] as String).length <= 500)
                {
                  'number': row['episode_number'],
                  'title': row['name'],
                  'aired': row['air_date'],
                  'runtime':
                      row['runtime'] is int &&
                          row['runtime'] > 0 &&
                          row['runtime'] <= 600
                      ? row['runtime']
                      : null,
                  'overview': row['overview'] is String
                      ? (row['overview'] as String).substring(
                          0,
                          (row['overview'] as String).length.clamp(0, 5000),
                        )
                      : '',
                  'still':
                      row['still_path'] is String &&
                          RegExp(
                            r'^/[A-Za-z0-9_.-]+$',
                          ).hasMatch(row['still_path'])
                      ? 'https://image.tmdb.org/t/p/w500${row['still_path']}'
                      : '',
                },
          ],
        };
      },
    );
    final rows = patch['episodes'];
    if (rows is! List) return base;
    final extras = <int, MediaEpisode>{};
    for (final row in rows) {
      if (row is! Map || row['number'] is! int || row['title'] is! String) {
        continue;
      }
      extras.putIfAbsent(
        row['number'],
        () => MediaEpisode(
          number: row['number'],
          title: row['title'],
          aired: DateTime.tryParse('${row['aired']}'),
          runtimeMinutes: row['runtime'] as int?,
          still: row['still'] as String? ?? '',
          overview: row['overview'] as String? ?? '',
        ),
      );
    }
    if (base.isEmpty) {
      return extras.values.toList()
        ..sort((a, b) => a.number.compareTo(b.number));
    }
    return [
      for (final episode in base)
        MediaEpisode(
          number: episode.number,
          title: episode.title,
          aired: episode.aired ?? extras[episode.number]?.aired,
          imdbId: episode.imdbId,
          runtimeMinutes: extras[episode.number]?.runtimeMinutes,
          still: extras[episode.number]?.still ?? '',
          overview: extras[episode.number]?.overview ?? '',
        ),
    ];
  }

  Future<Map<String, dynamic>> _tmdb(MediaTitle title, String token) async {
    final headers = {'Authorization': 'Bearer $token'};
    final mappingKey = 'tmdb-id:${title.kind}:${title.imdbId}';
    final mapping = _cache[mappingKey];
    int? tmdbId;
    if (mapping is Map &&
        mapping['expires'] is int &&
        mapping['expires'] > _now().millisecondsSinceEpoch &&
        mapping['id'] is int) {
      tmdbId = mapping['id'] as int;
    }
    if (tmdbId == null) {
      final found = await _get(
        Uri.https('api.themoviedb.org', '/3/find/${title.imdbId}', {
          'external_source': 'imdb_id',
        }),
        headers: headers,
      );
      final rows =
          found[title.kind == 'series' ? 'tv_results' : 'movie_results'];
      if (rows is! List ||
          rows.length != 1 ||
          rows.single is! Map ||
          rows.single['id'] is! int) {
        return {};
      }
      tmdbId = rows.single['id'] as int;
    }
    final kind = title.kind == 'series' ? 'tv' : 'movie';
    final response = await _get(
      Uri.https('api.themoviedb.org', '/3/$kind/$tmdbId', {
        'append_to_response': 'credits,keywords,external_ids,videos',
        'language': 'en-US',
      }),
      headers: headers,
    );
    if (response['id'] != tmdbId ||
        (response['external_ids'] as Map?)?['imdb_id'] != title.imdbId) {
      throw const MetadataException('identity');
    }
    _cache[mappingKey] = {
      'id': tmdbId,
      'expires': _now().add(const Duration(days: 90)).millisecondsSinceEpoch,
    };
    final credits = response['credits'];
    final cast = credits is Map && credits['cast'] is List
        ? credits['cast'] as List
        : const [];
    String image(Object? path) =>
        path is String && RegExp(r'^/[a-zA-Z0-9_.-]+$').hasMatch(path)
        ? 'https://image.tmdb.org/t/p/w185$path'
        : '';
    final keywordData = response['keywords'];
    final keywords = keywordData is Map
        ? (keywordData['keywords'] ?? keywordData['results'])
        : null;
    final trailer = selectTitleTrailer(response['videos']);
    return {
      if (trailer != null) 'trailer': trailer.toJson(),
      if (cast.isNotEmpty)
        'cast': [
          for (final person in cast.take(40))
            if (person is Map && person['name'] is String)
              {
                'name': person['name'],
                'character': person['character'],
                'photo': image(person['profile_path']),
              },
        ],
      if (keywords is List && keywords.isNotEmpty)
        'topics': [
          for (final keyword in keywords.take(30))
            if (keyword is Map && keyword['name'] is String) keyword['name'],
        ],
      if (title.poster.isEmpty && image(response['poster_path']).isNotEmpty)
        'Poster': image(response['poster_path']),
    };
  }

  Future<Map<String, dynamic>> _locations(MediaTitle title) async {
    // Fixed property vocabulary; only a normalized IMDb ID is interpolated.
    if (normalizeImdbId(title.imdbId) == null) return {};
    final query =
        'PREFIX wdt: <http://www.wikidata.org/prop/direct/> PREFIX wikibase: <http://wikiba.se/ontology#> PREFIX bd: <http://www.bigdata.com/rdf#> SELECT DISTINCT ?item ?property ?placeLabel WHERE { ?item wdt:P345 "${title.imdbId}". OPTIONAL { VALUES ?property { wdt:P915 wdt:P840 } ?item ?property ?place. } SERVICE wikibase:label { bd:serviceParam wikibase:language "en". } } LIMIT 60';
    final data = await _get(
      Uri.https('query.wikidata.org', '/sparql', {
        'format': 'json',
        'query': query,
      }),
    );
    final results = data['results'];
    final rows = results is Map ? results['bindings'] : null;
    if (rows is! List) return {};
    // Multiple items with the same external ID indicate an ambiguous mapping.
    final ids = {
      for (final row in rows)
        if (row is Map) (row['item'] as Map?)?['value'],
    };
    if (ids.length != 1) return {};
    List<String> values(String property) => {
      for (final row in rows)
        if (row is Map &&
            (row['property'] as Map?)?['value'] ==
                'http://www.wikidata.org/prop/direct/$property' &&
            (row['placeLabel'] as Map?)?['value'] is String)
          (row['placeLabel'] as Map)['value'] as String,
    }.take(30).toList();
    return {
      'filmingLocations': values('P915'),
      'narrativeLocations': values('P840'),
      if (ids.single is String &&
          RegExp(
            r'^http://www.wikidata.org/entity/Q[0-9]+$',
          ).hasMatch(ids.single as String))
        'locationSource': (ids.single as String).replaceFirst(
          'http://www.wikidata.org/entity/',
          'https://www.wikidata.org/wiki/',
        ),
    };
  }
}

class _EnrichmentBackoff implements Exception {
  const _EnrichmentBackoff(this.delay);
  final Duration delay;
}
