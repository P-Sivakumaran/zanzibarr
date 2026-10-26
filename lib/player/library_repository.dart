import 'dart:convert';
import 'media_preferences.dart';

/// Stable persistence seam for library features. Implementations must preserve
/// the previous readable snapshot when a mutation fails and never hide corruption.
abstract interface class LibraryRepository<T> {
  Future<List<T>> read();
  Future<void> write(List<T> values, {bool forgetPrevious = false});
  Future<void> clear();
}

class LibraryStorageException implements Exception {
  const LibraryStorageException();
  @override
  String toString() =>
      'Library data could not be recovered. Existing data was preserved.';
}

class UnsupportedLibrarySchema extends LibraryStorageException {
  const UnsupportedLibrarySchema();
}

/// Encrypted, bounded snapshots with last-good recovery. Callers serialize
/// read/modify/write operations; this is not a multi-record database transaction.
class SecureJsonLibraryRepository<T> implements LibraryRepository<T> {
  SecureJsonLibraryRepository({
    required this.storage,
    required this.key,
    required this.decode,
    required this.encode,
  });
  final PlayerPreferenceStorage storage;
  final String key;
  final T? Function(Object?) decode;
  final Map<String, Object?> Function(T) encode;
  static const maxBytes = 4 * 1024 * 1024;
  String get backupKey => '$key.last-good';

  List<T> _decode(String raw) {
    if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
      throw const LibraryStorageException();
    }
    try {
      final document = jsonDecode(raw);
      if (document is Map &&
          document['version'] != null &&
          document['version'] != 1) {
        throw const UnsupportedLibrarySchema();
      }
      if (document is! Map ||
          (document['version'] != null && document['version'] != 1) ||
          document['entries'] is! List) {
        throw const LibraryStorageException();
      }
      final result = <T>[];
      for (final value in document['entries'] as List) {
        final item = decode(value);
        if (item == null) throw const LibraryStorageException();
        result.add(item);
      }
      return result;
    } on UnsupportedLibrarySchema {
      rethrow;
    } catch (_) {
      throw const LibraryStorageException();
    }
  }

  @override
  Future<List<T>> read() async {
    final raw = await storage.read(key);
    if (raw == null) return [];
    try {
      return _decode(raw);
    } on UnsupportedLibrarySchema {
      rethrow;
    } on LibraryStorageException {
      final previous = await storage.read(backupKey);
      if (previous == null) rethrow;
      final recovered = _decode(previous);
      // Preserve damaged data in encrypted storage before restoring last-good.
      await storage.write('$key.damaged', raw);
      await storage.write(key, previous);
      if (await storage.read(key) != previous) {
        throw const LibraryStorageException();
      }
      return recovered;
    }
  }

  @override
  Future<void> write(List<T> values, {bool forgetPrevious = false}) async {
    final next = jsonEncode({
      'version': 1,
      'entries': values.map(encode).toList(),
    });
    if (utf8.encode(next).length > maxBytes) {
      throw const LibraryStorageException();
    }
    final previous = await storage.read(key);
    if (previous != null) {
      _decode(
        previous,
      ); // Do not overwrite unrecoverable data on a failed load.
      await storage.write(backupKey, previous);
    }
    await storage.write(key, next);
    if (await storage.read(key) != next) throw const LibraryStorageException();
    if (forgetPrevious) {
      await storage.delete(backupKey);
      await storage.delete('$key.damaged');
    }
  }

  @override
  Future<void> clear() async {
    await write(
      [],
    ); // Authoritative empty snapshot prevents stale resurrection.
    await storage.delete(backupKey);
    await storage.delete('$key.damaged');
  }
}
