import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/update/update_service.dart';

class _NoUpdates extends UpdateService {
  @override
  Future<ReleaseInfo?> checkForUpdate({bool ignoreSkipped = false}) async => null;
}

class _HistoryStore extends PlaybackHistoryStore {
  _HistoryStore(this.entries);
  List<PlaybackHistoryEntry> entries;

  @override
  Future<List<PlaybackHistoryEntry>> load() async => entries;

  @override
  Future<void> remove(String path, {String? entryKey}) async {
    entries.removeWhere(
      (entry) => entry.nzbPath == path && entry.entryKey == entryKey,
    );
  }

  @override
  Future<void> setFavorite(
    String nzbPath, {
    String? entryKey,
    required bool favorite,
  }) async {
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
      favorite: favorite,
    );
  }

  @override
  Future<void> setCompleted(
    String nzbPath, {
    String? entryKey,
    required bool completed,
  }) async {
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
      updatedAtMs: old.updatedAtMs,
      favorite: old.favorite,
    );
  }
}

Widget _app(Widget home) => ZanzibarrApp(home: home);

void main() {
  testWidgets('favori yıldızı dokununca Favoriler bölümünde görünür', (
    tester,
  ) async {
    final history = _HistoryStore([
      const PlaybackHistoryEntry(
        nzbPath: '/media/film.nzb',
        title: 'Film.mkv',
        positionSeconds: 30,
        durationSeconds: 6000,
        updatedAtMs: 1,
      ),
    ]);
    await tester.pumpWidget(
      _app(HomeScreen(historyStore: history, updateService: _NoUpdates())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsNothing);
    await tester.tap(find.byIcon(Icons.star_border_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(history.entries.single.favorite, isTrue);
  });

  testWidgets(
    'tamamlanmamış favori için izlendi işaretlenince Continue Watching\'den çıkar',
    (tester) async {
      final history = _HistoryStore([
        const PlaybackHistoryEntry(
          nzbPath: '/media/film.nzb',
          title: 'Film.mkv',
          positionSeconds: 30,
          durationSeconds: 6000,
          updatedAtMs: 1,
          favorite: true,
        ),
      ]);
      await tester.pumpWidget(
        _app(HomeScreen(historyStore: history, updateService: _NoUpdates())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue watching'), findsOneWidget);
      // Favori + devam eden kayıt aynı anda hem Continue Watching hem
      // Favoriler'de görünür; ikisi de aynı veriyi gösterir, hangisine
      // dokunulduğu sonucu değiştirmez.
      await tester.tap(find.byIcon(Icons.done_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Continue watching'), findsNothing);
      expect(history.entries.single.isCompleted, isTrue);
      // Favori olduğundan hâlâ Favoriler bölümünde kalır.
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Film.mkv'), findsOneWidget);
    },
  );

  testWidgets(
    'tamamlanmış favori için izlenmedi işaretlenince Continue Watching\'e geri döner',
    (tester) async {
      final history = _HistoryStore([
        const PlaybackHistoryEntry(
          nzbPath: '/media/film.nzb',
          title: 'Film.mkv',
          positionSeconds: 5900,
          durationSeconds: 6000,
          updatedAtMs: 1,
          favorite: true,
        ),
      ]);
      await tester.pumpWidget(
        _app(HomeScreen(historyStore: history, updateService: _NoUpdates())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue watching'), findsNothing);
      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Continue watching'), findsOneWidget);
      expect(history.entries.single.isCompleted, isFalse);
      expect(history.entries.single.positionSeconds, 0);
    },
  );

  testWidgets('favori yıldızı tekrar dokununca kaldırılır', (tester) async {
    final history = _HistoryStore([
      const PlaybackHistoryEntry(
        nzbPath: '/media/film.nzb',
        title: 'Film.mkv',
        positionSeconds: 30,
        durationSeconds: 6000,
        updatedAtMs: 1,
        favorite: true,
      ),
    ]);
    await tester.pumpWidget(
      _app(HomeScreen(historyStore: history, updateService: _NoUpdates())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsNothing);
    expect(history.entries.single.favorite, isFalse);
  });
}
