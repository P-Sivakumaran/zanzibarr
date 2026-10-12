import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/media_preferences.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/player/watchlist.dart';

class _MemoryPreferenceStorage implements PlayerPreferenceStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

PlaybackHistoryEntry _historyEntry({
  required String imdbId,
  required int season,
  required int episode,
  bool completed = true,
}) => PlaybackHistoryEntry(
  nzbPath: '/$imdbId-s${season}e$episode.nzb',
  title: 'show.mkv',
  positionSeconds: completed ? 5900 : 100,
  durationSeconds: 6000,
  updatedAtMs: 1000,
  imdbId: imdbId,
  season: season,
  episode: episode,
);

void main() {
  test('track ekler, tekrar track etmek yinelemez', () async {
    final store = WatchlistStore(storage: _MemoryPreferenceStorage());
    await store.track('tt1', 'Show One');
    await store.track('tt1', 'Show One');

    final entries = await store.load();
    expect(entries, hasLength(1));
    expect(entries.single.imdbId, 'tt1');
  });

  test('isTracked doğru döner', () async {
    final store = WatchlistStore(storage: _MemoryPreferenceStorage());
    await store.track('tt1', 'Show One');

    expect(await store.isTracked('tt1'), isTrue);
    expect(await store.isTracked('tt2'), isFalse);
  });

  test('untrack kaldırır', () async {
    final store = WatchlistStore(storage: _MemoryPreferenceStorage());
    await store.track('tt1', 'Show One');
    await store.untrack('tt1');

    expect(await store.load(), isEmpty);
  });

  test('markChecked son kontrol zamanını günceller', () async {
    final store = WatchlistStore(storage: _MemoryPreferenceStorage());
    await store.track('tt1', 'Show One');
    await store.markChecked('tt1');

    final entries = await store.load();
    expect(entries.single.lastCheckedAtMs, isNotNull);
  });

  test('nextUnwatchedEpisode geçmiş yoksa S01E01 döner', () {
    const tracked = WatchlistEntry(
      imdbId: 'tt1',
      title: 'Show One',
      addedAtMs: 0,
    );
    final result = nextUnwatchedEpisode(tracked, []);
    expect(result.season, 1);
    expect(result.episode, 1);
  });

  test('nextUnwatchedEpisode tamamlanmış bölümden sonrasını önerir', () {
    const tracked = WatchlistEntry(
      imdbId: 'tt1',
      title: 'Show One',
      addedAtMs: 0,
    );
    final result = nextUnwatchedEpisode(tracked, [
      _historyEntry(imdbId: 'tt1', season: 1, episode: 3, completed: true),
    ]);
    expect(result.season, 1);
    expect(result.episode, 4);
  });

  test(
    'nextUnwatchedEpisode devam eden bölümün kendisini önerir',
    () {
      const tracked = WatchlistEntry(
        imdbId: 'tt1',
        title: 'Show One',
        addedAtMs: 0,
      );
      final result = nextUnwatchedEpisode(tracked, [
        _historyEntry(imdbId: 'tt1', season: 2, episode: 1, completed: false),
      ]);
      expect(result.season, 2);
      expect(result.episode, 1);
    },
  );

  test('needsCheckReminder eşikten yeni ise false döner', () {
    final now = DateTime(2026, 1, 10);
    final entry = WatchlistEntry(
      imdbId: 'tt1',
      title: 'Show One',
      addedAtMs: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    );
    expect(needsCheckReminder(entry, now: now), isFalse);
  });

  test('needsCheckReminder eşikten eskiyse true döner', () {
    final now = DateTime(2026, 1, 10);
    final entry = WatchlistEntry(
      imdbId: 'tt1',
      title: 'Show One',
      addedAtMs: now.subtract(const Duration(days: 10)).millisecondsSinceEpoch,
    );
    expect(needsCheckReminder(entry, now: now), isTrue);
  });

  test('needsCheckReminder lastCheckedAtMs varsa onu esas alır', () {
    final now = DateTime(2026, 1, 10);
    final entry = WatchlistEntry(
      imdbId: 'tt1',
      title: 'Show One',
      addedAtMs: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
      lastCheckedAtMs: now
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
    );
    expect(needsCheckReminder(entry, now: now), isFalse);
  });
}
