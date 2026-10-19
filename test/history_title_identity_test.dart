import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'metadata_library_test.dart' show MemoryStorage;

void main() {
  test(
    'matching history preserves current progress, recovery and other inner files',
    () async {
      final storage = MemoryStorage();
      final history = PlaybackHistoryStore(storage: storage);
      const before = PlaybackHistoryEntry(
        nzbPath: '/saved/set.nzb',
        entryKey: 'one',
        title: 'Release',
        positionSeconds: 30,
        durationSeconds: 900,
        updatedAtMs: 1,
      );
      const current = PlaybackHistoryEntry(
        nzbPath: '/saved/set.nzb',
        entryKey: 'one',
        title: 'Release',
        positionSeconds: 350,
        durationSeconds: 900,
        updatedAtMs: 2,
        favorite: true,
        sourceId: 'stable',
        nzbUrl: 'https://indexer.example/release',
      );
      const other = PlaybackHistoryEntry(
        nzbPath: '/saved/set.nzb',
        entryKey: 'two',
        title: 'Other',
        positionSeconds: 20,
        durationSeconds: 900,
        updatedAtMs: 1,
      );
      await history.save(before);
      await history.save(other);
      await history.save(current);
      await history.setTitleIdentity(before, 'tt1234567');
      final rows = await history.load();
      final matched = rows.firstWhere((e) => e.entryKey == 'one');
      expect(matched.imdbId, 'tt1234567');
      expect(matched.positionSeconds, 350);
      expect(matched.favorite, true);
      expect(matched.sourceId, 'stable');
      expect(matched.nzbUrl, current.nzbUrl);
      expect(rows.firstWhere((e) => e.entryKey == 'two').imdbId, isNull);
      await expectLater(
        history.setTitleIdentity(before, 'tt2345678'),
        throwsStateError,
      );
      await history.remove(other.nzbPath, entryKey: other.entryKey);
      await expectLater(
        history.setTitleIdentity(other, 'tt1234567'),
        throwsStateError,
      );
      await history.load();
    },
  );
  test(
    'failed identity writes preserve the previous history and progress',
    () async {
      final storage = MemoryStorage();
      final history = PlaybackHistoryStore(storage: storage);
      const entry = PlaybackHistoryEntry(
        nzbPath: '/saved.nzb',
        title: 'Release',
        positionSeconds: 30,
        durationSeconds: 1000,
        updatedAtMs: 1,
      );
      await history.save(entry);
      storage.failWrite = true;
      await expectLater(
        history.setTitleIdentity(entry, 'tt1234567'),
        throwsStateError,
      );
      storage.failWrite = false;
      final rows = await history.load();
      expect(rows.single.imdbId, isNull);
      expect(rows.single.positionSeconds, 30);
    },
  );
}
