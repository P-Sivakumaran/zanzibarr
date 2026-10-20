import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../player/media_preferences.dart';

enum AdultSource { tpdb, stashdb }

extension AdultSourceLabel on AdultSource {
  String get label => this == AdultSource.tpdb ? 'ThePornDB' : 'StashDB';
}

String _text(dynamic value, [int limit = 300]) => value is String
    ? value.trim().substring(0, value.trim().length.clamp(0, limit))
    : '';

/// Provider IDs are separate from IMDb and release identities.
class AdultTitle {
  const AdultTitle({
    required this.source,
    required this.id,
    required this.title,
    this.kind = 'scene',
    this.studio = '',
    this.date = '',
    this.performers = const [],
    this.iafdUrl = '',
    this.artwork = '',
  });
  final AdultSource source;
  final String id, title, kind, studio, date, iafdUrl, artwork;
  final List<String> performers;
  String get identity => '${source.name}:$kind:$id';
  Map<String, dynamic> toJson() => {
    'source': source.name,
    'id': id,
    'title': title,
    'kind': kind,
    'studio': studio,
    'date': date,
    'performers': performers,
    'iafdUrl': iafdUrl,
    'artwork': artwork,
  };
  factory AdultTitle.fromJson(Map<String, dynamic> row) {
    final source = AdultSource.values.byName(row['source'] as String);
    final rawId = row['id'];
    if (rawId is! String || rawId.length > 100) {
      throw const FormatException('Invalid catalog identity');
    }
    final id = rawId.trim();
    final title = _text(row['title']);
    if (id.isEmpty ||
        title.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid catalog identity');
    }
    return AdultTitle(
      source: source,
      id: id,
      title: title,
      kind: row['kind'] == 'movie' ? 'movie' : 'scene',
      studio: _text(row['studio']),
      date: _text(row['date'], 20),
      artwork: adultArtworkUri(_text(row['artwork'], 2000))?.toString() ?? '',
      iafdUrl: iafdReference(row['iafdUrl'])?.toString() ?? '',
      performers:
          (row['performers'] is List ? row['performers'] as List : const [])
              .take(100)
              .map((v) => _text(v))
              .where((v) => v.isNotEmpty)
              .toList(),
    );
  }
}

Uri? adultArtworkUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.userInfo.isEmpty &&
          !uri.hasPort &&
          uri.query.isEmpty &&
          uri.fragment.isEmpty &&
          const {'cdn.theporndb.net', 'thumb.theporndb.net'}.contains(uri.host)
      ? uri
      : null;
}

Uri? iafdReference(dynamic value) {
  if (value is! String || value.length > 2000) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          const {'iafd.com', 'www.iafd.com'}.contains(uri.host) &&
          uri.userInfo.isEmpty &&
          !uri.hasPort &&
          uri.fragment.isEmpty
      ? uri
      : null;
}

class AdultCatalogFailure implements Exception {
  const AdultCatalogFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Explicit searches only; fixed origins, no redirects, bounded bodies and time.
class AdultCatalog {
  AdultCatalog({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  bool _busy = false;
  DateTime? _retryAt;
  void close() => _client.close();
  Future<List<AdultTitle>> search(
    AdultSource source,
    String token,
    String query, {
    bool movies = false,
  }) async {
    if (_busy) {
      throw const AdultCatalogFailure('A catalog request is already running.');
    }
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
      throw const AdultCatalogFailure(
        'The source asked us to wait. Try again later.',
      );
    }
    final term = query.trim();
    if (term.length < 2 ||
        term.length > 200 ||
        token.trim().isEmpty ||
        token.length > 4096) {
      throw const AdultCatalogFailure(
        'Enter a source API key and a search of 2 to 200 characters.',
      );
    }
    if (movies && source == AdultSource.stashdb) {
      throw const AdultCatalogFailure(
        'StashDB searches scenes. Choose ThePornDB for movies.',
      );
    }
    _busy = true;
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 15), () => abort.complete());
    try {
      final tpdb = source == AdultSource.tpdb;
      final request = http.AbortableRequest(
        tpdb ? 'GET' : 'POST',
        tpdb
            ? Uri.https('api.theporndb.net', movies ? '/movies' : '/scenes', {
                'q': term,
                'per_page': '20',
                'page': '1',
              })
            : Uri.https('stashdb.org', '/graphql'),
        abortTrigger: abort.future,
      )..followRedirects = false;
      request.headers.addAll({
        'Accept': 'application/json',
        if (tpdb)
          'Authorization': 'Bearer ${token.trim()}'
        else
          'ApiKey': token.trim(),
      });
      if (!tpdb) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({
          'query':
              r'query Catalog($term:String!){searchScene(term:$term,limit:20){id title release_date deleted studio{name} performers{performer{name}}}}',
          'variables': {'term': term},
        });
      }
      final response = await _client.send(request);
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _retryAt = DateTime.now().add(
          Duration(seconds: seconds.clamp(1, 3600)),
        );
        throw const AdultCatalogFailure(
          'Source rate limit reached. Try again later.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AdultCatalogFailure(
          'Source access was refused. Check your API key and account permissions.',
        );
      }
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > 2 * 1024 * 1024) {
        throw const AdultCatalogFailure(
          'The source could not return catalog data.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const AdultCatalogFailure('The source response was too large.');
        }
        bytes.addAll(chunk);
      }
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (body['errors'] != null) {
        throw const AdultCatalogFailure(
          'The source rejected the catalog query.',
        );
      }
      final rows =
          (tpdb ? body['data'] : (body['data'] as Map?)?['searchScene'])
              as List;
      final titles = <AdultTitle>[];
      for (final value in rows.take(20)) {
        if (value is! Map || value['deleted'] == true) continue;
        try {
          final performers = value['performers'] as List? ?? [];
          final links = value['links'];
          String iafd = '';
          if (links is Map) {
            for (final link in links.values) {
              final uri = iafdReference(link);
              if (uri != null) {
                iafd = uri.toString();
                break;
              }
            }
          }
          final title = AdultTitle.fromJson({
            'source': source.name,
            'id': value['id'],
            'title': value['title'],
            'kind': movies ? 'movie' : 'scene',
            'studio': (tpdb ? value['site'] : value['studio'])?['name'],
            'date': value[tpdb ? 'date' : 'release_date'],
            'iafdUrl': iafd,
            'artwork': tpdb
                ? (value['poster'] ??
                      (value['background'] as Map?)?['large'] ??
                      value['image'])
                : null,
            'performers': [
              for (final p in performers)
                if (p is Map)
                  tpdb ? p['name'] : (p['performer'] as Map?)?['name'],
            ],
          });
          if (!titles.any((t) => t.identity == title.identity)) {
            titles.add(title);
          }
        } catch (_) {
          /* Malformed rows never become matches. */
        }
      }
      return titles;
    } on AdultCatalogFailure {
      rethrow;
    } catch (_) {
      throw const AdultCatalogFailure(
        'Catalog request failed. Check the connection and try again.',
      );
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _busy = false;
    }
  }
}

/// Kept separate from mainstream matches; changes are serialized and durable.
class AdultLibraryStore {
  AdultLibraryStore({PlayerPreferenceStorage? storage})
    : storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage storage;
  static final shared = AdultLibraryStore();
  Future<void> _pending = Future.value();
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<AdultTitle>> load() => _serial(_load);
  Future<List<AdultTitle>> _load() async {
    final raw = await storage.read('adult.library.v1');
    if (raw == null) return [];
    final rows = jsonDecode(raw);
    if (rows is! List || rows.length > 300) {
      throw const FormatException('Invalid adult library');
    }
    return [
      for (final row in rows)
        AdultTitle.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<void> save(AdultTitle title, {String? replacing}) => _serial(() async {
    final rows = await _load();
    rows.removeWhere(
      (t) => t.identity == title.identity || t.identity == replacing,
    );
    if (rows.length >= 300) {
      throw const AdultCatalogFailure('Library limit reached (300 titles).');
    }
    rows.insert(0, title);
    await storage.write(
      'adult.library.v1',
      jsonEncode(rows.map((t) => t.toJson()).toList()),
    );
  });
  Future<void> remove(String identity) => _serial(() async {
    final rows = await _load();
    rows.removeWhere((t) => t.identity == identity);
    await storage.write(
      'adult.library.v1',
      jsonEncode(rows.map((t) => t.toJson()).toList()),
    );
  });
}
