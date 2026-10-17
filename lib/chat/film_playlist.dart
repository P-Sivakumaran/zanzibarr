import 'dart:async';
import 'dart:convert';

import '../integrations/integration_settings.dart';
import '../player/media_preferences.dart';
import '../search/release_search_selection.dart';

class FilmSuggestion {
  const FilmSuggestion({
    required this.title,
    required this.year,
    required this.description,
    required this.reason,
  });
  final String title;
  final int? year;
  final String description;
  final String reason;
  String get identity => '${title.toLowerCase().trim()}:$year';
  // AI identifiers are not trusted to constrain release searches.
  ReleaseSearchSelection get selection =>
      ReleaseSearchSelection(title: title, year: year, kind: 'movie');
  Map<String, Object?> toJson() => {
    'title': title,
    'year': year,
    'description': description,
    'reason': reason,
  };
  factory FilmSuggestion.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid film');
    final year = value['year'];
    if (year != null && (year is! int || year < 1880 || year > 2200)) {
      throw const FormatException('Invalid year');
    }
    return FilmSuggestion(
      title: boundedText(value['title'], 200),
      year: year as int?,
      description: boundedText(value['description'], 2000),
      reason: boundedText(value['reason'], 1000),
    );
  }
}

String boundedText(Object? value, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw const FormatException('Invalid text');
  }
  return value.trim();
}

class FilmReply {
  const FilmReply(this.message, this.films);
  final String message;
  final List<FilmSuggestion> films;
  factory FilmReply.parse(String text) {
    if (text.length > 64000) throw const FormatException('Reply too large');
    final value = jsonDecode(text);
    if (value is! Map ||
        value['films'] is! List ||
        (value['films'] as List).length > 12) {
      throw const FormatException('Invalid reply');
    }
    final seen = <String>{};
    final films = [
      for (final film in value['films']) FilmSuggestion.fromJson(film),
    ];
    return FilmReply(
      boundedText(value['message'], 8000),
      List.unmodifiable(films.where((film) => seen.add(film.identity))),
    );
  }
}

class FilmPlaylist {
  FilmPlaylist({
    required this.id,
    required this.name,
    required List<FilmSuggestion> films,
  }) : films = List.unmodifiable(films);
  final String id;
  final String name;
  final List<FilmSuggestion> films;
  FilmPlaylist copyWith({String? name, List<FilmSuggestion>? films}) =>
      FilmPlaylist(id: id, name: name ?? this.name, films: films ?? this.films);
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'films': [for (final film in films) film.toJson()],
  };
  factory FilmPlaylist.fromJson(Object? value) {
    if (value is! Map ||
        value['films'] is! List ||
        (value['films'] as List).length > 100) {
      throw const FormatException('Invalid playlist');
    }
    final films = [
      for (final film in value['films']) FilmSuggestion.fromJson(film),
    ];
    if (films.map((f) => f.identity).toSet().length != films.length) {
      throw const FormatException('Duplicate film');
    }
    return FilmPlaylist(
      id: boundedText(value['id'], 100),
      name: boundedText(value['name'], 100),
      films: films,
    );
  }
}

class FilmPlaylistStore {
  FilmPlaylistStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage _storage;
  static const key = 'zanzibarr.film-playlists.v1';
  // Instance-scoped: a `static` queue here would serialize every
  // FilmPlaylistStore in the process onto one chain, so a single stuck
  // operation (slow storage, abandoned future) would silently hang every
  // other instance's load/save forever, not just this one's.
  Future<void> _pending = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<FilmPlaylist>> load() => _serialized(_load);

  Future<List<FilmPlaylist>> _load() async {
    try {
      final text = await _storage.read(key);
      if (text == null) return [];
      if (text.length > 2000000) throw const FormatException('Too large');
      final value = jsonDecode(text);
      if (value is! Map ||
          value['version'] != 1 ||
          value['playlists'] is! List) {
        throw const FormatException('Invalid playlists');
      }
      final lists = [
        for (final p in value['playlists']) FilmPlaylist.fromJson(p),
      ];
      _validate(lists);
      return lists;
    } catch (_) {
      throw const IntegrationException(
        'Playlists could not be loaded. Saved data was preserved. Retry to continue.',
      );
    }
  }

  void _validate(List<FilmPlaylist> lists) {
    if (lists.length > 20 ||
        lists.map((p) => p.id).toSet().length != lists.length) {
      throw const FormatException('Invalid playlists');
    }
    for (final list in lists) {
      FilmPlaylist.fromJson(list.toJson());
    }
  }

  Future<void> save(
    List<FilmPlaylist> lists, {
    List<FilmPlaylist>? expected,
  }) => _serialized(() async {
    try {
      _validate(lists);
      if (expected != null) {
        final current = await _load();
        String snapshot(List<FilmPlaylist> value) =>
            jsonEncode([for (final playlist in value) playlist.toJson()]);
        if (snapshot(current) != snapshot(expected)) {
          throw const IntegrationException(
            'Playlists changed in another screen. Reload playlists before editing; your saved lists are safe.',
          );
        }
      }
      final text = jsonEncode({
        'version': 1,
        'playlists': [for (final p in lists) p.toJson()],
      });
      if (text.length > 2000000) throw const FormatException('Too large');
      await _storage.write(key, text);
    } on IntegrationException {
      rethrow;
    } catch (_) {
      throw const IntegrationException(
        'Could not save playlists. Your previous saved list is unchanged; please retry.',
      );
    }
  });
}
