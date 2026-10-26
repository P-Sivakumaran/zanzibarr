import 'library_repository.dart';

import 'media_preferences.dart';

/// Bir medyanın izleme geçmişi kaydı: son konum ve toplam süre.
///
/// Kayıtlar [PlaybackHistoryStore] içinde JSON listesi olarak saklanır.
/// Kaydın kimliği `(nzbPath, entryKey)` çiftidir: çok parçalı (sezon
/// paketi gibi) NZB'lerde her bölüm kendi kaydını taşır; tek adaylı
/// NZB'lerde `entryKey` null'dır (eski kayıtlarla uyumlu).
class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.nzbPath,
    required this.title,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAtMs,
    this.entryKey,
    this.imdbId,
    this.season,
    this.episode,
    this.sourceId,
    this.nzbUrl,
    this.favorite = false,
  });

  /// Geçmiş kaydının kimliği: NZB'nin dosya yolu (yerel depoda kalır).
  final String nzbPath;

  /// Çok parçalı NZB'de oynatılan bölümün seçici anahtarı (ör.
  /// `rar:show.s01e02`); tek adaylı NZB'lerde null. Aynı NZB'nin
  /// bölümleri birbirinin konumunu ezmesin diye kimliğin parçasıdır.
  final String? entryKey;

  /// Kartlarda gösterilen ad (video dosya adı).
  final String title;

  final double positionSeconds;
  final double durationSeconds;
  final int updatedAtMs;

  /// Yapılandırılmış aramadan (OMDb eşleşmesi) geldiyse IMDb kimliği; aynı
  /// gösterinin bölümlerini gruplamak için kullanılır. Serbest metin
  /// aramasından/dosya seçiciden gelen kayıtlarda null kalır — her
  /// release'in kimliği olmak zorunda değil.
  final String? imdbId;

  /// Release adından Rust tarafında ayrıştırılan sezon/bölüm; `imdbId` ile
  /// birlikte "Sıradaki" özelliğinin temelini oluşturur.
  final int? season;
  final int? episode;

  /// Aramadan geldiyse indirmenin kaynağı: hangi indexer profilinden
  /// (`sourceId`) ve hangi URL'den (`nzbUrl`) indirildiği. `nzbPath` geçici
  /// önbellek dizinine işaret eder ve sistem temizliğinde ya da yeniden
  /// başlatma sonrası sessizce kaybolabilir; bu ikisi varsa devam ederken
  /// dosya yoksa aynı NZB yeniden indirilebilir (Faz 4 — resume durability).
  /// Dosya seçiciden açılan oynatmalarda null kalır (indirilecek bir kaynak
  /// yok, yeniden indirme de söz konusu değil).
  final String? sourceId;
  final String? nzbUrl;

  /// İzleme ilerlemesinden bağımsız elle işaretlenen favori ("tekrar
  /// izlemek istiyorum" — Faz 5). Favori kayıtlar bütçe aşıldığında
  /// tamamlanmış kayıtlar arasından silinecek adaylar listesine girmez
  /// (bkz. [PlaybackHistoryStore.save]).
  final bool favorite;

  /// İzleme sona erdiyse (son ~%3) kayıt tutulmaz; baştan başlatılır.
  bool get isCompleted =>
      durationSeconds > 0 && positionSeconds >= durationSeconds * 0.97;

  /// 0–1 arası izleme ilerlemesi; süre bilinmiyorsa 0.
  double get progress => durationSeconds > 0
      ? (positionSeconds / durationSeconds).clamp(0.0, 1.0)
      : 0;

  Duration get position =>
      Duration(milliseconds: (positionSeconds * 1000).round());

  Map<String, Object> toJson() => <String, Object>{
    'nzbPath': nzbPath,
    'entryKey': ?entryKey,
    'title': title,
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
    'updatedAtMs': updatedAtMs,
    'imdbId': ?imdbId,
    'season': ?season,
    'episode': ?episode,
    'sourceId': ?sourceId,
    'nzbUrl': ?nzbUrl,
    'favorite': favorite,
  };

  static PlaybackHistoryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final path = value['nzbPath'];
    final title = value['title'];
    final position = value['positionSeconds'];
    final duration = value['durationSeconds'];
    final updatedAt = value['updatedAtMs'];
    if (path is! String || path.isEmpty) return null;
    if (title is! String) return null;
    if (position is! num || duration is! num || updatedAt is! num) {
      return null;
    }
    final entryKey = value['entryKey'];
    final imdbId = value['imdbId'];
    final season = value['season'];
    final episode = value['episode'];
    final sourceId = value['sourceId'];
    final nzbUrl = value['nzbUrl'];
    final favorite = value['favorite'];
    return PlaybackHistoryEntry(
      nzbPath: path,
      entryKey: entryKey is String && entryKey.isNotEmpty ? entryKey : null,
      title: title,
      positionSeconds: position.toDouble(),
      durationSeconds: duration.toDouble(),
      updatedAtMs: updatedAt.toInt(),
      imdbId: imdbId is String && imdbId.isNotEmpty ? imdbId : null,
      season: season is num ? season.toInt() : null,
      episode: episode is num ? episode.toInt() : null,
      sourceId: sourceId is String && sourceId.isNotEmpty ? sourceId : null,
      nzbUrl: nzbUrl is String && nzbUrl.isNotEmpty ? nzbUrl : null,
      favorite: favorite == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackHistoryEntry &&
      nzbPath == other.nzbPath &&
      entryKey == other.entryKey &&
      title == other.title &&
      positionSeconds == other.positionSeconds &&
      durationSeconds == other.durationSeconds &&
      updatedAtMs == other.updatedAtMs &&
      imdbId == other.imdbId &&
      season == other.season &&
      episode == other.episode &&
      sourceId == other.sourceId &&
      nzbUrl == other.nzbUrl &&
      favorite == other.favorite;

  @override
  int get hashCode => Object.hash(
    nzbPath,
    entryKey,
    title,
    positionSeconds,
    durationSeconds,
    updatedAtMs,
    imdbId,
    season,
    episode,
    sourceId,
    nzbUrl,
    favorite,
  );
}

/// İzleme geçmişini güvenli depoda (şifreli) tutar; en güncel kayıt başta
/// olacak şekilde sıralıdır ve liste [_maxEntries] ile sınırlanır.
class PlaybackHistoryStore {
  PlaybackHistoryStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();

  final PlayerPreferenceStorage _storage;
  late final LibraryRepository<PlaybackHistoryEntry> _repository =
      SecureJsonLibraryRepository<PlaybackHistoryEntry>(
        storage: _storage,
        key: storageKey,
        decode: PlaybackHistoryEntry.fromJson,
        encode: (entry) => entry.toJson(),
      );

  static const storageKey = 'zanzibarr.playback_history.v1';
  static const _maxEntries = 25;

  // Home and Player create separate stores backed by the same secure key.
  // Serialize reads and mutations across those instances, including failed writes.
  static Future<void> _pending = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<PlaybackHistoryEntry>> load() => _serialized(_load);

  Future<List<PlaybackHistoryEntry>> _load() => _repository.read();

  /// Look up the exact file, or the same release after a fresh download.
  /// Source and URL must both match; titles alone cannot identify a release.
  Future<PlaybackHistoryEntry?> entryFor(
    String nzbPath, {
    String? entryKey,
    String? mediaTitle,
    String? sourceId,
    String? nzbUrl,
  }) => _serialized(() async {
    final entries = List.of(await _load());
    for (final entry in entries) {
      if (entry.nzbPath == nzbPath && entry.entryKey == entryKey) return entry;
    }
    bool sameRelease(PlaybackHistoryEntry entry) =>
        entry.nzbPath == nzbPath ||
        (sourceId != null &&
            sourceId.isNotEmpty &&
            nzbUrl != null &&
            nzbUrl.isNotEmpty &&
            entry.sourceId == sourceId &&
            entry.nzbUrl == nzbUrl);
    bool sameVideo(PlaybackHistoryEntry entry) =>
        entry.entryKey == entryKey ||
        (entryKey != null &&
            entry.entryKey == null &&
            mediaTitle != null &&
            mediaTitle.isNotEmpty &&
            entry.title == mediaTitle);

    final matches =
        entries.where((e) => sameRelease(e) && sameVideo(e)).toList()
          ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    if (matches.isEmpty) return null;
    final previous = matches.first;
    final migrated = PlaybackHistoryEntry(
      nzbPath: nzbPath,
      entryKey: entryKey,
      title: previous.title,
      positionSeconds: previous.positionSeconds,
      durationSeconds: previous.durationSeconds,
      updatedAtMs: previous.updatedAtMs,
      imdbId: previous.imdbId,
      season: previous.season,
      episode: previous.episode,
      sourceId: previous.sourceId,
      nzbUrl: previous.nzbUrl,
      favorite: previous.favorite,
    );
    // Move the record atomically. Do not consume another history slot or
    // retain duplicate cards for earlier downloads of this same video.
    entries.removeWhere((e) => sameRelease(e) && sameVideo(e));
    entries.add(migrated);
    entries.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    await _write(entries);
    return migrated;
  });

  /// Kaydı ekler veya günceller.
  ///
  /// Tamamlanmış kayıt da tutulur (silinmez): "Sıradaki" özelliği hangi
  /// bölümün izlendiğini bilmek için bu kayda ihtiyaç duyar. Aynı NZB
  /// yeniden açıldığında tamamlanmış kaydı silip baştan başlatan asıl yer
  /// [PlayerScreen._loadHistoryPosition]'dir — burada silmek o akışı bozar.
  ///
  /// Legacy records are replaced only when they describe the same video.
  Future<void> save(PlaybackHistoryEntry entry) => _serialized(() async {
    final entries = List.of(await _load());
    if (entries.any(
      (e) =>
          e.nzbPath == entry.nzbPath &&
          e.entryKey == entry.entryKey &&
          e.updatedAtMs > entry.updatedAtMs,
    )) {
      return;
    }
    entries.removeWhere(
      (e) =>
          e.nzbPath == entry.nzbPath &&
          (e.entryKey == entry.entryKey ||
              (entry.entryKey != null &&
                  e.entryKey == null &&
                  e.title == entry.title)),
    );
    entries.insert(0, entry);
    // Tamamlanmış kayıtlar da artık tutulduğu için aynı 25'lik bütçeyi
    // devam edenlerle paylaşıyor; sınır aşılırsa önce en eski tamamlanmış
    // kayıtlar düşer, devam edilebilir (resume) konumlar korunur (code
    // review bulgusu — aksi halde çok bölüm tamamlamak eski bir filmin
    // yarım kalan konumunu sessizce silebilirdi). Favori işaretli kayıtlar
    // bu ilk turda aday değildir — "tekrar izlemek istiyorum" ilerlemeden
    // bağımsız kalmalı (Faz 5).
    var excess = entries.length - _maxEntries;
    // 1. tur: en eski tamamlanmış, favori olmayan kayıtlar düşer.
    for (var i = entries.length - 1; i >= 0 && excess > 0; i--) {
      if (entries[i].isCompleted && !entries[i].favorite) {
        entries.removeAt(i);
        excess--;
      }
    }
    // 2. tur (yedek): yeterli tamamlanmış aday yoksa, en eski devam eden
    // (favori olmayan) kayıtlar düşer. Favoriler burada da korunur — aksi
    // halde eski bir favori, 24 devam eden kayıt arasında sessizce silinirdi
    // (code review bulgusu: önceki haliyle bu yedek tur doğrudan en eskiyi
    // düşürüyordu, favori olup olmadığına bakmadan).
    if (excess > 0) {
      for (var i = entries.length - 1; i >= 0 && excess > 0; i--) {
        if (!entries[i].favorite) {
          entries.removeAt(i);
          excess--;
        }
      }
    }
    // Son çare: her şey favoriyse (tüm bütçe favorilerle dolmuşsa) en eski
    // kayıt(lar) düşer — sınırsız depolamaya izin verilmez.
    if (excess > 0) {
      entries.removeRange(entries.length - excess, entries.length);
    }
    await _write(entries);
  });

  Future<void> remove(String nzbPath, {String? entryKey}) =>
      _serialized(() async {
        final entries = List.of(await _load());
        entries.removeWhere(
          (e) => e.nzbPath == nzbPath && e.entryKey == entryKey,
        );
        await _repository.write(entries, forgetPrevious: true);
      });

  /// Bir kaydın kimliğini ([oldPath]/`entryKey`) aynı listede yerinde
  /// değiştirir — konum/süre dahil her şey korunur. Geçici önbellek dosyası
  /// kaybolup aynı NZB yeniden indirildiğinde kullanılır (Faz 4). `save` +
  /// `remove` ayrı çağrıldığında liste 25 kayıtla doluyken geçici 26.
  /// kayıt kapasite kırpmasını tetikleyip BAŞKA bir videonun kaydını
  /// düşürebiliyordu (code review bulgusu) — burada uzunluk hiç değişmediği
  /// için kırpma devreye girmez.
  Future<void> migratePath({
    required String oldPath,
    String? entryKey,
    required String newPath,
  }) => _serialized(() async {
    final entries = List.of(await _load());
    final index = entries.indexWhere(
      (e) => e.nzbPath == oldPath && e.entryKey == entryKey,
    );
    if (index < 0) return;
    final old = entries[index];
    entries[index] = PlaybackHistoryEntry(
      nzbPath: newPath,
      entryKey: old.entryKey,
      title: old.title,
      positionSeconds: old.positionSeconds,
      durationSeconds: old.durationSeconds,
      updatedAtMs: old.updatedAtMs,
      imdbId: old.imdbId,
      season: old.season,
      episode: old.episode,
      sourceId: old.sourceId,
      nzbUrl: old.nzbUrl,
      favorite: old.favorite,
    );
    await _write(entries);
  });

  /// Favori işaretini aynı listede yerinde değiştirir; konum/süre dahil
  /// her şey korunur, uzunluk değişmediği için kapasite kırpması devreye
  /// girmez (Faz 5).
  Future<void> setFavorite(
    String nzbPath, {
    String? entryKey,
    required bool favorite,
  }) => _serialized(() async {
    final entries = List.of(await _load());
    final index = entries.indexWhere(
      (e) => e.nzbPath == nzbPath && e.entryKey == entryKey,
    );
    if (index < 0) return;
    final old = entries[index];
    entries[index] = PlaybackHistoryEntry(
      nzbPath: old.nzbPath,
      entryKey: old.entryKey,
      title: old.title,
      positionSeconds: old.positionSeconds,
      durationSeconds: old.durationSeconds,
      updatedAtMs: old.updatedAtMs,
      imdbId: old.imdbId,
      season: old.season,
      episode: old.episode,
      sourceId: old.sourceId,
      nzbUrl: old.nzbUrl,
      favorite: favorite,
    );
    await _write(entries);
  });

  /// İzleme ilerlemesini fiilen oynatmadan zorlar: tamamlandı işaretlenirse
  /// konum süreye eşitlenir, tamamlanmamış işaretlenirse baştan başlatılır
  /// (Faz 5 — "mark watched/unwatched"). Süre bilinmiyorsa (hiç oynatılmamış
  /// bir kayıt) tamamlandı olarak işaretlemek anlamsızdır; no-op.
  Future<void> setCompleted(
    String nzbPath, {
    String? entryKey,
    required bool completed,
  }) => _serialized(() async {
    final entries = List.of(await _load());
    final index = entries.indexWhere(
      (e) => e.nzbPath == nzbPath && e.entryKey == entryKey,
    );
    if (index < 0) return;
    final old = entries[index];
    if (completed && old.durationSeconds <= 0) return;
    entries[index] = PlaybackHistoryEntry(
      nzbPath: old.nzbPath,
      entryKey: old.entryKey,
      title: old.title,
      positionSeconds: completed ? old.durationSeconds : 0,
      durationSeconds: old.durationSeconds,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      imdbId: old.imdbId,
      season: old.season,
      episode: old.episode,
      sourceId: old.sourceId,
      nzbUrl: old.nzbUrl,
      favorite: old.favorite,
    );
    await _write(entries);
  });

  /// Associate only the exact release the user matched. Preserve newer playback
  /// progress, source recovery and favorites; never recreate a deleted entry.
  Future<void> setTitleIdentity(PlaybackHistoryEntry expected, String imdbId) =>
      _serialized(() async {
        if (!RegExp(r'^tt[0-9]{7,10}$').hasMatch(imdbId)) {
          throw const FormatException('Invalid title identity');
        }
        final entries = List.of(await _load());
        final index = entries.indexWhere(
          (e) =>
              e.nzbPath == expected.nzbPath && e.entryKey == expected.entryKey,
        );
        if (index < 0) throw StateError('History entry no longer exists');
        final old = entries[index];
        if (old.title != expected.title || old.imdbId != expected.imdbId) {
          throw StateError('History identity changed');
        }
        entries[index] = PlaybackHistoryEntry(
          nzbPath: old.nzbPath,
          entryKey: old.entryKey,
          title: old.title,
          positionSeconds: old.positionSeconds,
          durationSeconds: old.durationSeconds,
          updatedAtMs: old.updatedAtMs,
          imdbId: imdbId,
          season: old.season,
          episode: old.episode,
          sourceId: old.sourceId,
          nzbUrl: old.nzbUrl,
          favorite: old.favorite,
        );
        await _write(entries);
      });

  Future<void> _write(List<PlaybackHistoryEntry> entries) =>
      _repository.write(entries);
}
