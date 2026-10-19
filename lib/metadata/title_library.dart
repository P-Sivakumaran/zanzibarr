import 'dart:convert';
import '../player/media_preferences.dart';
import 'metadata_service.dart';

class LibraryFull implements Exception {
  const LibraryFull();
}

/// Saved title metadata only; no release URLs, credentials or viewing history.
class TitleLibraryStore {
  TitleLibraryStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage _storage;
  static final shared = TitleLibraryStore();
  Future<void> _pending = Future.value();
  static const _key = 'metadata.library.v1';
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<MediaTitle>> load() => _serial(_load);
  Future<List<MediaTitle>> _load() async {
    final raw = await _storage.read(_key);
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List || data.length > 300) {
      throw const FormatException('Invalid library');
    }
    return [
      for (final row in data)
        MediaTitle.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<void> save(MediaTitle title) => _serial(() async {
    final titles = await _load();
    if (titles.length >= 300 && !titles.any((t) => t.imdbId == title.imdbId)) {
      throw const LibraryFull();
    }
    titles.removeWhere((t) => t.imdbId == title.imdbId);
    titles.insert(0, title);
    await _storage.write(
      _key,
      jsonEncode(titles.map((t) => t.toJson()).toList()),
    );
  });
  Future<void> remove(String id) => _serial(() async {
    final titles = await _load();
    titles.removeWhere((t) => t.imdbId == id);
    await _storage.write(
      _key,
      jsonEncode(titles.map((t) => t.toJson()).toList()),
    );
  });
}
