import '../editions/edition_storage.dart';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tek bir Newznab indexer profili.
///
/// API anahtarı yalnızca OS secure storage'da (Keychain/Keystore) tutulur;
/// hiçbir sır kaynak koda veya düz metin dosyaya yazılmaz.
class IndexerProfile {
  const IndexerProfile({
    required this.id,
    this.nickname = '',
    this.baseUrl = '',
    this.apiKey = '',
    this.enabled = true,
  });

  /// Kararlı tanımlayıcı; listede yeniden sıralama/düzenleme boyunca sabit
  /// kalır. Depolama anahtarı değil, yalnızca UI/eşleme için.
  final String id;

  /// Kullanıcının bu indexer'a verdiği ad (ör. "NZBFinder"). Boşsa UI ve
  /// kaynak rozetleri base URL'e düşer.
  final String nickname;

  /// Indexer'ın kök adresi (ör. `https://indexer.example`; sonunda `/api`
  /// olabilir ya da olmayabilir, Rust tarafı normalize eder).
  final String baseUrl;

  /// Newznab API anahtarı.
  final String apiKey;

  /// Kapalı profiller aramaya dahil edilmez ama ayarlarda saklı kalır.
  final bool enabled;

  /// Rozet/attribution metninde gösterilecek görünen ad.
  String get displayName => nickname.isNotEmpty ? nickname : baseUrl;

  /// İki alan da doluysa profil kullanılabilir kabul edilir.
  bool get isComplete => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  IndexerProfile copyWith({
    String? nickname,
    String? baseUrl,
    String? apiKey,
    bool? enabled,
  }) => IndexerProfile(
    id: id,
    nickname: nickname ?? this.nickname,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> _toJson() => {
    'id': id,
    'nickname': nickname,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'enabled': enabled,
  };

  static IndexerProfile _fromJson(Map<String, dynamic> json) => IndexerProfile(
    id: json['id'] as String,
    nickname: json['nickname'] as String? ?? '',
    baseUrl: json['baseUrl'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );
}

/// Yerleşik indexer ön ayarları: kullanıcı yalnızca API anahtarını yapıştırır.
/// Liste zamanla değişebilir indexer'lar için; "Özel" seçeneği her zaman
/// serbest URL girişine izin verir.
class KnownIndexer {
  const KnownIndexer(this.name, this.baseUrl);

  final String name;
  final String baseUrl;
}

const knownIndexers = [
  KnownIndexer('NZBFinder', 'https://nzbfinder.ws'),
  KnownIndexer('NZBgeek', 'https://api.nzbgeek.info'),
  KnownIndexer('nzb.su', 'https://api.nzb.su'),
  KnownIndexer('NZBPlanet', 'https://nzbplanet.net'),
  KnownIndexer('DrunkenSlug', 'https://drunkenslug.com'),
];

/// [IndexerProfile] listesi için OS secure storage üzerinde kalıcı depo.
///
/// Profiller tek bir JSON blobu olarak saklanır (secure storage'da yapısal
/// liste desteği yok); her profilin kendi anahtar/URL çifti bu blobun
/// içinde kalır, ayrı ayrı anahtarlanmaz.
class IndexerSettingsStore {
  IndexerSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const EditionSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kProfiles = 'indexer.profiles.v2';

  // Eski tek-indexer biçimi; yalnızca bir kerelik geçiş için okunur.
  static const _kLegacyBaseUrl = 'indexer.baseUrl';
  static const _kLegacyApiKey = 'indexer.apiKey';
  static const _kLegacyNickname = 'indexer.nickname';

  Future<List<IndexerProfile>> load() async {
    final raw = await _storage.read(key: _kProfiles);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .cast<Map<String, dynamic>>()
            .map(IndexerProfile._fromJson)
            .toList();
      } catch (_) {
        // Never replace unreadable stored credentials with an empty list.
        throw const FormatException(
          'Stored indexer profiles could not be read',
        );
      }
    }

    // Eski tek-indexer kaydı var mı? Varsa tek profile göç et ve eski
    // anahtarları temizle.
    final legacyBaseUrl = await _storage.read(key: _kLegacyBaseUrl);
    final legacyApiKey = await _storage.read(key: _kLegacyApiKey);
    if (legacyBaseUrl != null || legacyApiKey != null) {
      final legacyNickname = await _storage.read(key: _kLegacyNickname) ?? '';
      final migrated = [
        IndexerProfile(
          id: 'migrated-0',
          nickname: legacyNickname,
          baseUrl: legacyBaseUrl ?? '',
          apiKey: legacyApiKey ?? '',
        ),
      ];
      await save(migrated);
      for (final key in [_kLegacyBaseUrl, _kLegacyApiKey, _kLegacyNickname]) {
        await _storage.delete(key: key);
      }
      return migrated;
    }

    return const [];
  }

  Future<void> save(List<IndexerProfile> profiles) async {
    final raw = jsonEncode(profiles.map((p) => p._toJson()).toList());
    await _storage.write(key: _kProfiles, value: raw);
  }

  Future<void> clear() async {
    for (final key in [
      _kProfiles,
      _kLegacyBaseUrl,
      _kLegacyApiKey,
      _kLegacyNickname,
    ]) {
      await _storage.delete(key: key);
    }
  }
}
