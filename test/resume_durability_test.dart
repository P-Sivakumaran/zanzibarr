import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/settings/indexer_settings.dart';
import 'package:zanzibarr/settings/provider_settings.dart';
import 'package:zanzibarr/src/rust/api/search.dart';
import 'package:zanzibarr/update/update_service.dart';

class _NoUpdates extends UpdateService {
  @override
  Future<ReleaseInfo?> checkForUpdate() async => null;
}

class _ProviderStore extends ProviderSettingsStore {
  ProviderSettings value = const ProviderSettings(
    host: 'news.example.com',
    username: 'user',
    password: 'TESTPASS123',
  );
  @override
  Future<ProviderSettings> load() async => value;
  @override
  Future<void> save(ProviderSettings settings) async => value = settings;
}

class _IndexerStore extends IndexerSettingsStore {
  _IndexerStore(this.value);
  List<IndexerProfile> value;
  @override
  Future<List<IndexerProfile>> load() async => value;
  @override
  Future<void> save(List<IndexerProfile> profiles) async => value = profiles;
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
}

const _trackedProfile = IndexerProfile(
  id: 'idx1',
  baseUrl: 'https://indexer.example',
  apiKey: 'TESTPASS123',
);

const _withSource = PlaybackHistoryEntry(
  nzbPath: '/cache/vanished.nzb',
  title: 'Show.S01E01.mkv',
  positionSeconds: 30,
  durationSeconds: 120,
  updatedAtMs: 1,
  sourceId: 'idx1',
  nzbUrl: 'https://indexer.example/nzb/show-s01e01',
);

const _withoutSource = PlaybackHistoryEntry(
  nzbPath: '/cache/vanished-manual.nzb',
  title: 'Manual pick.mkv',
  positionSeconds: 30,
  durationSeconds: 120,
  updatedAtMs: 1,
);

Widget _app(Widget home) => ZanzibarrApp(home: home);

void main() {
  testWidgets('mevcut dosya doğrudan açılır, yeniden indirme denenmez', (
    tester,
  ) async {
    var downloadCalled = false;
    String? openedPath;
    await tester.pumpWidget(
      _app(
        HomeScreen(
          historyStore: _HistoryStore([_withSource]),
          providerStore: _ProviderStore(),
          updateService: _NoUpdates(),
          fileExistsFn: (_) async => true,
          downloadFn: (config, nzbUrl, suggestedName) async {
            downloadCalled = true;
            return '/should-not-be-used.nzb';
          },
          playerBuilder: (path, key) {
            openedPath = path;
            return const Scaffold(body: Text('Playback started'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show.S01E01.mkv'));
    await tester.tap(find.text('Show.S01E01.mkv'));
    await tester.pumpAndSettle();

    expect(downloadCalled, isFalse);
    expect(openedPath, '/cache/vanished.nzb');
  });

  testWidgets(
    'dosya kayıpsa ve kaynak biliniyorsa yeniden indirilip açılır',
    (tester) async {
      final history = _HistoryStore([_withSource]);
      String? openedPath;
      IndexerConfigDto? usedConfig;
      await tester.pumpWidget(
        _app(
          HomeScreen(
            historyStore: history,
            indexerStore: _IndexerStore([_trackedProfile]),
            providerStore: _ProviderStore(),
            updateService: _NoUpdates(),
            fileExistsFn: (_) async => false,
            downloadFn: (config, nzbUrl, suggestedName) async {
              usedConfig = config;
              return '/cache/fresh.nzb';
            },
            playerBuilder: (path, key) {
              openedPath = path;
              return const Scaffold(body: Text('Playback started'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show.S01E01.mkv'));
      await tester.tap(find.text('Show.S01E01.mkv'));
      await tester.pumpAndSettle();

      expect(openedPath, '/cache/fresh.nzb');
      expect(usedConfig?.id, 'idx1');
      expect(
        history.entries.any((e) => e.nzbPath == '/cache/vanished.nzb'),
        isFalse,
        reason: 'stale ghost entry at the old path must be cleaned up',
      );
    },
  );

  testWidgets(
    'dosya kayıpsa ve kaynak bilgisi yoksa (dosya seçiciden açılmış) hata gösterilir',
    (tester) async {
      var downloadCalled = false;
      await tester.pumpWidget(
        _app(
          HomeScreen(
            historyStore: _HistoryStore([_withoutSource]),
            updateService: _NoUpdates(),
            fileExistsFn: (_) async => false,
            downloadFn: (config, nzbUrl, suggestedName) async {
              downloadCalled = true;
              return '/unused.nzb';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Manual pick.mkv'));
      await tester.tap(find.text('Manual pick.mkv'));
      await tester.pumpAndSettle();

      expect(downloadCalled, isFalse);
      expect(
        find.text(
          "This file is no longer available and can't be re-downloaded.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'dosya kayıpsa ve orijinal indexer artık yoksa hata gösterilir',
    (tester) async {
      await tester.pumpWidget(
        _app(
          HomeScreen(
            historyStore: _HistoryStore([_withSource]),
            indexerStore: _IndexerStore(const []),
            updateService: _NoUpdates(),
            fileExistsFn: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show.S01E01.mkv'));
      await tester.tap(find.text('Show.S01E01.mkv'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "This file is no longer available; its original indexer isn't configured anymore.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'yeniden indirme başarısız olursa hata gösterilir, geçmiş kaydı korunur',
    (tester) async {
      final history = _HistoryStore([_withSource]);
      await tester.pumpWidget(
        _app(
          HomeScreen(
            historyStore: history,
            indexerStore: _IndexerStore([_trackedProfile]),
            updateService: _NoUpdates(),
            fileExistsFn: (_) async => false,
            downloadFn: (config, nzbUrl, suggestedName) async {
              throw StateError('network down');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show.S01E01.mkv'));
      await tester.tap(find.text('Show.S01E01.mkv'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This file is no longer available and could not be re-downloaded.',
        ),
        findsOneWidget,
      );
      expect(
        history.entries.any((e) => e.nzbPath == '/cache/vanished.nzb'),
        isTrue,
        reason: 'failed recovery must not delete the still-valid record',
      );
    },
  );
}
