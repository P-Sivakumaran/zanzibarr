import '../search/release_search_selection.dart';
import '../metadata/title_resolver.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../metadata/metadata_service.dart';
import '../player/media_preferences.dart';
import 'film_playlist.dart';

/// A bounded cache of automatically resolved and corrected matches. AI JSON never populates
/// provider identities, artwork or scores. Playlist storage stays compatible.
class SuggestionMetadata extends ChangeNotifier {
  SuggestionMetadata({
    MetadataService? service,
    MetadataSettingsStore? settings,
    PlayerPreferenceStorage? storage,
  }) : service = service ?? MetadataService(),
       settings = settings ?? MetadataSettingsStore(),
       _storage = storage ?? FlutterSecurePlayerPreferenceStorage(),
       _ownsService = service == null;
  final MetadataService service;
  final MetadataSettingsStore settings;
  final PlayerPreferenceStorage _storage;
  final bool _ownsService;
  final _matches = <String, MediaTitle>{};
  final _identities = <String, MediaTitle>{};
  String? error;
  bool _closed = false;
  bool _ready = false;
  late final _resolver = TitleResolver(service, settings);
  final _attempted = <String>{};
  final _loadingFilms = <String>{};
  final _revisions = <String, int>{};
  Future<void> _writes = Future.value();
  Future<void>? _loadPending;
  bool isLoading(FilmSuggestion film) => _loadingFilms.contains(film.identity);
  void resetAttempts() => _attempted.clear();
  Future<void> enrichAll(Iterable<FilmSuggestion> films) async {
    if (!_ready) await load();
    for (final film in films.take(100)) {
      if (_closed) return;
      await enrich(film);
    }
  }

  Future<void> enrich(FilmSuggestion film) async {
    if (!_ready) await load();
    final cached = _matches[film.identity];
    final chosen = cached ?? _identities[film.identity];
    final refresh =
        cached == null ||
        (cached.ratings.containsKey('IMDb') &&
            !cached.ratingCounts.containsKey('IMDb')) ||
        (cached.fetchedAt != null &&
            DateTime.now().difference(cached.fetchedAt!) >
                const Duration(hours: 6));
    if (_closed ||
        error != null ||
        !refresh ||
        !_attempted.add(film.identity)) {
      return;
    }
    final revision = _revisions[film.identity] ?? 0;
    _loadingFilms.add(film.identity);
    notifyListeners();
    try {
      final details = await _resolver.resolve(
        title: film.title,
        year: film.year,
        imdbId: chosen?.imdbId,
        kind: film.kind == DiscoveryKind.tv ? 'series' : 'movie',
      );
      if (details != null &&
          !_closed &&
          details.kind ==
              (film.kind == DiscoveryKind.tv ? 'series' : 'movie')) {
        await _save(film, details, revision);
      }
    } catch (_) {
      /* Keep the suggestion usable; rematch can retry. */
    } finally {
      _loadingFilms.remove(film.identity);
      if (!_closed) notifyListeners();
    }
  }

  static const _key = 'metadata.suggestion-matches.v1';
  static const _durableKey = 'metadata.suggestion-identities.v2';
  MediaTitle? forFilm(FilmSuggestion film) =>
      _matches[film.identity] ?? _identities[film.identity];
  ReleaseSearchSelection selectionFor(FilmSuggestion film) {
    final media = forFilm(film);
    return media == null
        ? film.selection
        : ReleaseSearchSelection.fromMedia(media);
  }

  Future<void> load() {
    final pending = _loadPending;
    if (pending != null) return pending;
    final next = _load();
    _loadPending = next;
    return next.whenComplete(() => _loadPending = null);
  }

  Future<void> _load() async {
    try {
      final durable = await _storage.read(_durableKey);
      final raw = durable ?? await _storage.read(_key);
      if (raw != null) {
        if (raw.length > 2 * 1024 * 1024) throw const FormatException();
        final decoded = jsonDecode(raw);
        final rows = durable == null ? decoded : decoded['matches'];
        if (rows is! Map || rows.length > 100) throw const FormatException();
        final next = <String, MediaTitle>{};
        for (final entry in rows.entries) {
          if (entry.key is! String ||
              (entry.key as String).length > 250 ||
              entry.value is! Map) {
            throw const FormatException();
          }
          next[entry.key as String] = MediaTitle.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
        final identities = <String, MediaTitle>{};
        if (durable != null) {
          final saved = decoded['identities'];
          if (saved is! Map || saved.length > 5000) {
            throw const FormatException();
          }
          for (final e in saved.entries) {
            if (e.key is! String ||
                (e.key as String).length > 250 ||
                e.value is! Map) {
              throw const FormatException();
            }
            identities[e.key as String] = MediaTitle.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            );
          }
        } else {
          identities.addAll(next);
        }
        _matches
          ..clear()
          ..addAll(next);
        _identities
          ..clear()
          ..addAll(identities);
      }
      error = null;
      _ready = true;
    } catch (_) {
      error =
          'Saved artwork matches could not be loaded. Retry before matching titles.';
    }
    if (!_closed) notifyListeners();
  }

  Future<List<MediaTitle>> candidates(FilmSuggestion film) async {
    if (!_ready || error != null) throw const MetadataException('storage');
    final key = await settings.load();
    if (key.isEmpty) throw const MetadataException('key');
    final page = await service.search(
      key,
      film.title,
      kind: film.kind == DiscoveryKind.tv ? 'series' : 'movie',
    );
    return page.titles
        .where(
          (title) =>
              title.kind ==
              (film.kind == DiscoveryKind.tv ? 'series' : 'movie'),
        )
        .toList();
  }

  Future<void> confirm(FilmSuggestion film, MediaTitle candidate) async {
    if (!_ready || error != null) throw const MetadataException('storage');
    if (candidate.kind !=
        (film.kind == DiscoveryKind.tv ? 'series' : 'movie')) {
      throw const MetadataException('response');
    }
    final revision = (_revisions[film.identity] ?? 0) + 1;
    _revisions[film.identity] = revision;
    final key = await settings.load();
    if (key.isEmpty) throw const MetadataException('key');
    final details = await service.details(key, candidate.imdbId);
    if (_closed) return;
    if (details == null ||
        details.imdbId != candidate.imdbId ||
        details.kind != candidate.kind) {
      throw const MetadataException('response');
    }
    await _save(film, details, revision);
  }

  Future<void> _save(FilmSuggestion film, MediaTitle details, int revision) {
    final result = _writes.then((_) async {
      if (_closed || (_revisions[film.identity] ?? 0) != revision) return;
      final next = {..._matches}..remove(film.identity);
      if (next.length >= 100) next.remove(next.keys.first);
      next[film.identity] = details;
      final identities = {..._identities};
      if (!identities.containsKey(film.identity) && identities.length >= 5000) {
        throw const MetadataException('identity-storage-full');
      }
      identities[film.identity] = MediaTitle(
        imdbId: details.imdbId,
        title: details.title,
        year: details.year,
        kind: details.kind,
      );
      final encoded = jsonEncode({
        'matches': {for (final e in next.entries) e.key: e.value.toJson()},
        'identities': {
          for (final e in identities.entries) e.key: e.value.toJson(),
        },
      });
      if (encoded.length > 2 * 1024 * 1024) {
        throw const MetadataException('storage');
      }
      await _storage.write(_durableKey, encoded);
      _matches
        ..clear()
        ..addAll(next);
      _identities
        ..clear()
        ..addAll(identities);
      if (!_closed) notifyListeners();
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  void dispose() {
    _closed = true;
    _resolver.close();
    if (_ownsService) service.close();
    super.dispose();
  }
}
