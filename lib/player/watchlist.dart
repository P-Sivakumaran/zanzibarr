import 'library_repository.dart';

import 'media_preferences.dart';
import 'playback_history.dart';

/// Takip edilen bir gösteri. Hangi bölümün izlendiği burada tutulmaz —
/// [nextUnwatchedEpisode] bunu izleme geçmişinden çıkarır; bu alan sadece
/// gösterinin ne zaman eklendiğini ve son ne zaman kontrol edildiğini
/// tutar ("bir süredir kontrol edilmedi" hatırlatması için).
class WatchlistEntry {
  const WatchlistEntry({
    required this.imdbId,
    required this.title,
    required this.addedAtMs,
    this.lastCheckedAtMs,
  });

  final String imdbId;
  final String title;
  final int addedAtMs;
  final int? lastCheckedAtMs;

  WatchlistEntry checkedAt(int atMs) => WatchlistEntry(
    imdbId: imdbId,
    title: title,
    addedAtMs: addedAtMs,
    lastCheckedAtMs: atMs,
  );

  Map<String, Object> toJson() => <String, Object>{
    'imdbId': imdbId,
    'title': title,
    'addedAtMs': addedAtMs,
    'lastCheckedAtMs': ?lastCheckedAtMs,
  };

  static WatchlistEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final imdbId = value['imdbId'];
    final title = value['title'];
    final addedAt = value['addedAtMs'];
    if (imdbId is! String || imdbId.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    if (addedAt is! num) return null;
    final lastChecked = value['lastCheckedAtMs'];
    return WatchlistEntry(
      imdbId: imdbId,
      title: title,
      addedAtMs: addedAt.toInt(),
      lastCheckedAtMs: lastChecked is num ? lastChecked.toInt() : null,
    );
  }
}

/// Bir gösteri için "sıradaki bölüm" hesabı: izleme geçmişinde o gösteriye
/// ait numaralandırılmış bir kayıt varsa oradan (ağ çağrısı yok, her zaman
/// güncel); yoksa S01E01'den başlar. Tamamlanmış kaydın bir sonrası,
/// devam eden kaydın kendisi önerilir (henüz bitmemiş).
({int season, int episode}) nextUnwatchedEpisode(
  WatchlistEntry tracked,
  List<PlaybackHistoryEntry> history,
) {
  final numbered = history.where(
    (e) => e.imdbId == tracked.imdbId && e.season != null && e.episode != null,
  );
  if (numbered.isEmpty) return (season: 1, episode: 1);

  final latest = numbered.reduce((a, b) {
    if (a.season! != b.season!) return a.season! > b.season! ? a : b;
    return a.episode! > b.episode! ? a : b;
  });
  return latest.isCompleted
      ? (season: latest.season!, episode: latest.episode! + 1)
      : (season: latest.season!, episode: latest.episode!);
}

/// Son kontrolden (veya hiç kontrol edilmediyse eklenmesinden) [threshold]
/// süreden fazla geçtiyse hatırlatma rozeti gösterilmeli.
bool needsCheckReminder(
  WatchlistEntry entry, {
  Duration threshold = const Duration(days: 7),
  DateTime? now,
}) {
  final last = entry.lastCheckedAtMs ?? entry.addedAtMs;
  final elapsedMs = (now ?? DateTime.now()).millisecondsSinceEpoch - last;
  return elapsedMs > threshold.inMilliseconds;
}

/// Takip listesini güvenli depoda tutar; en son eklenen başta.
class WatchlistStore {
  WatchlistStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();

  final PlayerPreferenceStorage _storage;
  late final LibraryRepository<WatchlistEntry> _repository =
      SecureJsonLibraryRepository<WatchlistEntry>(
        storage: _storage,
        key: storageKey,
        decode: WatchlistEntry.fromJson,
        encode: (entry) => entry.toJson(),
      );

  static const storageKey = 'zanzibarr.watchlist.v1';

  // Takip/takibi bırakma düğmesine art arda basılması gibi örtüşen
  // okuma-değiştirme-yazma çağrılarını sıralar; aksi halde ikisi de eski
  // listeyi okur ve biri diğerinin değişikliğini geri yazarak kaybeder
  // (code review bulgusu — bkz. PlaybackHistoryStore'daki aynı desen).
  static Future<void> _pending = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<WatchlistEntry>> load() => _serialized(_load);

  Future<List<WatchlistEntry>> _load() => _repository.read();

  Future<bool> isTracked(String imdbId) async =>
      (await _serialized(_load)).any((e) => e.imdbId == imdbId);

  Future<void> track(String imdbId, String title) => _serialized(() async {
    final entries = List.of(await _load());
    if (entries.any((e) => e.imdbId == imdbId)) return;
    entries.insert(
      0,
      WatchlistEntry(
        imdbId: imdbId,
        title: title,
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _write(entries);
  });

  Future<void> untrack(String imdbId) => _serialized(() async {
    final entries = List.of(await _load());
    entries.removeWhere((e) => e.imdbId == imdbId);
    await _repository.write(entries, forgetPrevious: true);
  });

  Future<void> markChecked(String imdbId) => _serialized(() async {
    final entries = List.of(await _load());
    final index = entries.indexWhere((e) => e.imdbId == imdbId);
    if (index < 0) return;
    entries[index] = entries[index].checkedAt(
      DateTime.now().millisecondsSinceEpoch,
    );
    await _write(entries);
  });

  Future<void> _write(List<WatchlistEntry> entries) =>
      _repository.write(entries);
}
