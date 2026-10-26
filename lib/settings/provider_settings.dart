import 'dart:convert';
import '../editions/edition_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// NNTP sağlayıcı ayarları.
///
/// Kimlik bilgileri yalnızca OS secure storage'da (Keychain/Keystore) tutulur;
/// hiçbir sır kaynak koda veya düz metin dosyaya yazılmaz.
class ProviderSettings {
  const ProviderSettings({
    this.host = '',
    this.port = 563,
    this.username = '',
    this.password = '',
    this.maxConnections = 10,
  });

  /// NNTP sunucu adresi (ör. sağlayıcının TLS host'u).
  final String host;

  /// NNTPS portu; 563 = TLS.
  final int port;

  final String username;
  final String password;

  /// Sağlayıcının izin verdiği eşzamanlı bağlantı sayısı.
  /// Faz 1'deki bağlantı havuzunun boyutu buradan gelir.
  final int maxConnections;

  bool get isComplete =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
}

/// [ProviderSettings] için OS secure storage üzerinde kalıcı depo.
class ProviderSettingsStore {
  ProviderSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const EditionSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kHost = 'provider.host';
  static const _kPort = 'provider.port';
  static const _kUsername = 'provider.username';
  static const _kPassword = 'provider.password';
  static const _kMaxConnections = 'provider.maxConnections';

  static const recordKey = 'provider.settings.v2';
  static Future<void> _pending = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ProviderSettings> load() => _serialized(() async {
    final record = await _storage.read(key: recordKey);
    if (record != null) {
      try {
        final value = jsonDecode(record);
        if (value is! Map ||
            value['version'] != 2 ||
            value['host'] is! String ||
            value['username'] is! String ||
            value['password'] is! String ||
            value['port'] is! int ||
            value['maxConnections'] is! int) {
          throw const FormatException();
        }
        final settings = ProviderSettings(
          host: value['host'] as String,
          port: value['port'] as int,
          username: value['username'] as String,
          password: value['password'] as String,
          maxConnections: value['maxConnections'] as int,
        );
        _validate(settings);
        return settings;
      } catch (_) {
        // Never fall back to stale legacy credentials after a record exists.
        throw StateError(
          'Provider settings could not be read. Re-enter your settings.',
        );
      }
    }
    const defaults = ProviderSettings();
    return ProviderSettings(
      host: await _storage.read(key: _kHost) ?? defaults.host,
      port:
          int.tryParse(await _storage.read(key: _kPort) ?? '') ?? defaults.port,
      username: await _storage.read(key: _kUsername) ?? defaults.username,
      password: await _storage.read(key: _kPassword) ?? defaults.password,
      maxConnections:
          int.tryParse(await _storage.read(key: _kMaxConnections) ?? '') ??
          defaults.maxConnections,
    );
  });

  static void _validate(ProviderSettings settings) {
    if (settings.port < 1 ||
        settings.port > 65535 ||
        settings.maxConnections < 1 ||
        settings.maxConnections > 100) {
      throw ArgumentError('Invalid provider port or connection limit');
    }
  }

  Future<void> save(ProviderSettings settings) =>
      _serialized(() => _save(settings));

  Future<void> _save(
    ProviderSettings settings, {
    bool requireCleanup = false,
  }) async {
    _validate(settings);
    final record = jsonEncode({
      'version': 2,
      'host': settings.host,
      'port': settings.port,
      'username': settings.username,
      'password': settings.password,
      'maxConnections': settings.maxConnections,
    });
    // One secure record avoids mixed fields if a write is interrupted.
    await _storage.write(key: recordKey, value: record);
    if (await _storage.read(key: recordKey) != record) {
      throw StateError(
        'Provider settings could not be verified. Please retry.',
      );
    }
    // Legacy keys remain recoverable until the complete record is verified.
    // Cleanup failure cannot invalidate the authoritative new record.
    for (final key in [
      _kHost,
      _kPort,
      _kUsername,
      _kPassword,
      _kMaxConnections,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        if (requireCleanup) {
          throw StateError('Provider credential cleanup failed. Please retry.');
        }
      }
    }
  }

  Future<void> clear() =>
      _serialized(() => _save(const ProviderSettings(), requireCleanup: true));
}
