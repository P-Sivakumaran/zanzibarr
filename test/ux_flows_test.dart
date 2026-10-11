import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/search/search_screen.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/settings/indexer_settings.dart';
import 'package:zanzibarr/settings/provider_settings.dart';
import 'package:zanzibarr/settings/settings_screen.dart';
import 'package:zanzibarr/settings/ui_preferences.dart';
import 'package:zanzibarr/src/rust/api/search.dart';
import 'package:zanzibarr/update/update_service.dart';

class _ProviderStore extends ProviderSettingsStore {
  ProviderSettings value = const ProviderSettings(
    host: 'news.example.com',
    username: 'user',
    password: 'TESTPASS123',
  );
  bool failSave = false;
  int saves = 0;
  @override
  Future<ProviderSettings> load() async => value;
  @override
  Future<void> save(ProviderSettings settings) async {
    if (failSave) throw StateError('write failed');
    value = settings;
    saves++;
  }
}

class _IndexerStore extends IndexerSettingsStore {
  _IndexerStore({bool complete = true})
    : value = complete
          ? const [
              IndexerProfile(
                id: '1',
                baseUrl: 'https://indexer.example',
                apiKey: 'TESTPASS123',
              ),
            ]
          : const [];
  List<IndexerProfile> value;
  @override
  Future<List<IndexerProfile>> load() async => value;
  @override
  Future<void> save(List<IndexerProfile> profiles) async => value = profiles;
}

class _NoUpdates extends UpdateService {
  @override
  Future<ReleaseInfo?> checkForUpdate() async => null;
}

class _HistoryStore extends PlaybackHistoryStore {
  bool failLoad = false;
  bool failRemove = false;
  final entries = [
    const PlaybackHistoryEntry(
      nzbPath: '/pending.nzb',
      entryKey: 'direct:episode',
      title: 'Pending episode',
      positionSeconds: 30,
      durationSeconds: 120,
      updatedAtMs: 1,
    ),
  ];
  @override
  Future<List<PlaybackHistoryEntry>> load() async {
    if (failLoad) throw StateError('read failed');
    return entries;
  }

  @override
  Future<void> remove(String path, {String? entryKey}) async {
    if (failRemove) throw StateError('write failed');
    entries.removeWhere(
      (entry) => entry.nzbPath == path && entry.entryKey == entryKey,
    );
  }
}

SearchItemDto _item(String id) => SearchItemDto(
  title: 'Release.$id.S01E01.1080p',
  nzbUrl: 'https://indexer.example/$id',
  badges: const [],
  mediaKind: 'tv',
  sourceIndexer: 'https://indexer.example',
);

Widget _app(Widget home) => ZanzibarrApp(home: home);

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.tap(find.byTooltip('Search'));
  await tester.pumpAndSettle();
}

Future<void> _settingsRoute(WidgetTester tester, SettingsScreen screen) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('Open settings'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'history read failures offer retry and failed removal preserves the item',
    (tester) async {
      final history = _HistoryStore()..failLoad = true;
      await tester.pumpWidget(
        _app(HomeScreen(historyStore: history, updateService: _NoUpdates())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Continue watching could not be loaded.'),
        findsOneWidget,
      );
      history.failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      history.failRemove = true;
      await tester.ensureVisible(find.byTooltip('Remove from history'));
      await tester.tap(find.byTooltip('Remove from history'));
      await tester.pumpAndSettle();
      expect(find.text('Pending episode'), findsOneWidget);
      expect(
        find.text('This item could not be removed. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('search diagnostics redact the active API key and URLs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SearchScreen(
          store: _IndexerStore(),
          searchFn: (_, query, limit, offset) async => throw StateError(
            'denied TESTPASS123 https://indexer.example/?apikey=TESTPASS123',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _search(tester, 'release');
    expect(find.textContaining('TESTPASS123'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TESTPASS123'), findsNothing);
    expect(find.textContaining('[URL]'), findsOneWidget);
  });

  testWidgets('search results remain usable in a narrow RTL layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = UiPreferencesController(UiPreferencesStore())
      ..locale = const Locale('ar');
    await tester.pumpWidget(
      ZanzibarrApp(
        uiPreferences: prefs,
        home: SearchScreen(
          store: _IndexerStore(),
          searchFn: (_, query, limit, offset) async => SearchManyResultDto(
            page: SearchPageDto(items: [_item('rtl')]),
            failedIndexers: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'release');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.text(_item('rtl').title))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SelectableText, _item('rtl').title),
      findsOneWidget,
    );
  });

  testWidgets('provider setup preserves the pending NZB and selected episode', (
    tester,
  ) async {
    final provider = _ProviderStore()..value = const ProviderSettings();
    String? openedPath;
    String? openedKey;
    await tester.pumpWidget(
      _app(
        HomeScreen(
          providerStore: provider,
          historyStore: _HistoryStore(),
          updateService: _NoUpdates(),
          playerBuilder: (path, key) {
            openedPath = path;
            openedKey = key;
            return const Scaffold(body: Text('Playback started'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pending episode'));
    await tester.tap(find.text('Pending episode'));
    await tester.pumpAndSettle();
    expect(openedPath, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Server address'),
      'news.example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'user',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'TESTPASS123',
    );
    await tester.scrollUntilVisible(
      find.text('Save securely'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save securely'));
    await tester.pumpAndSettle();
    expect(openedPath, '/pending.nzb');
    expect(openedKey, 'direct:episode');
    expect(find.text('Playback started'), findsOneWidget);
  });

  testWidgets(
    'pagination retries the same query and deduplicates overlapping pages',
    (tester) async {
      final offsets = <int>[];
      final queries = <String>[];
      var fail = true;
      await tester.pumpWidget(
        _app(
          SearchScreen(
            store: _IndexerStore(),
            searchFn: (config, query, limit, offset) async {
              offsets.add(offset);
              queries.add(query);
              if (offset == 0) {
                return SearchManyResultDto(
                  page: SearchPageDto(
                    total: BigInt.from(4),
                    items: [_item('a'), _item('b')],
                  ),
                  failedIndexers: const [],
                );
              }
              if (fail) {
                fail = false;
                throw StateError('offline');
              }
              return SearchManyResultDto(
                page: SearchPageDto(
                  total: BigInt.from(4),
                  items: [_item('b'), _item('c')],
                ),
                failedIndexers: const [],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _search(tester, 'original');
      expect(find.text('Showing 2 of 4'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'edited but not submitted',
      );
      await tester.tap(find.text('Load more results'));
      await tester.pumpAndSettle();
      expect(
        find.text('More results could not be loaded. Try again.'),
        findsOneWidget,
      );
      expect(find.text(_item('a').title), findsOneWidget);
      await tester.tap(find.text('Load more results'));
      await tester.pumpAndSettle();
      expect(offsets, [0, 2, 2]);
      expect(queries, ['original', 'original', 'original']);
      expect(find.text(_item('b').title), findsOneWidget);
      expect(find.text(_item('c').title), findsOneWidget);
      expect(find.text('Load more results'), findsNothing);
    },
  );

  testWidgets('clearing a pending search ignores its late result', (
    tester,
  ) async {
    final result = Completer<SearchManyResultDto>();
    await tester.pumpWidget(
      _app(
        SearchScreen(
          store: _IndexerStore(),
          searchFn: (_, query, limit, offset) => result.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pending');
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    result.complete(
      SearchManyResultDto(
        page: SearchPageDto(total: BigInt.one, items: [_item('late')]),
        failedIndexers: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_item('late').title), findsNothing);
  });

  testWidgets('search release details expose the complete long filename', (
    tester,
  ) async {
    final item = _item('very.long.shared.prefix.' * 8);
    await tester.pumpWidget(
      _app(
        SearchScreen(
          store: _IndexerStore(),
          searchFn: (_, query, limit, offset) async => SearchManyResultDto(
            page: SearchPageDto(items: [item]),
            failedIndexers: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _search(tester, 'release');
    await tester.tap(find.byTooltip('Release details'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SelectableText, item.title), findsOneWidget);
  });

  testWidgets('provider test uses draft values and does not save them', (
    tester,
  ) async {
    final store = _ProviderStore();
    ProviderSettings? tested;
    await tester.pumpWidget(
      _app(
        SettingsScreen(
          store: store,
          initialSection: SettingsSection.provider,
          providerCheckFn: (settings) async {
            tested = settings;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'draft-user',
    );
    await tester.scrollUntilVisible(
      find.text('Test provider connection'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Test provider connection'));
    await tester.pumpAndSettle();
    expect(tested?.username, 'draft-user');
    expect(store.saves, 0);
    expect(
      find.text(
        'Connection and authentication succeeded. Save any changes to keep them.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('unsaved provider changes support keep editing and discard', (
    tester,
  ) async {
    final store = _ProviderStore();
    await _settingsRoute(
      tester,
      SettingsScreen(store: store, initialSection: SettingsSection.provider),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'draft-user',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('draft-user'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    expect(store.saves, 0);
  });

  testWidgets('failed save on leave keeps the draft and route open', (
    tester,
  ) async {
    final store = _ProviderStore()..failSave = true;
    await _settingsRoute(
      tester,
      SettingsScreen(store: store, initialSection: SettingsSection.provider),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'draft-user',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('draft-user'), findsOneWidget);
    expect(
      find.text(
        'Changes could not be saved. Keep this screen open and try again.',
      ),
      findsOneWidget,
    );
    store.failSave = false;
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(store.value.username, 'draft-user');
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets(
    'home indexer setup opens the relevant form then continues to search',
    (tester) async {
      final indexer = _IndexerStore(complete: false);
      await tester.pumpWidget(
        _app(HomeScreen(indexerStore: indexer, updateService: _NoUpdates())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search the indexer'));
      await tester.pumpAndSettle();
      expect(find.text('NNTP connection'), findsNothing);
      await tester.tap(find.text('Add indexer'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Indexer URL'),
        'https://indexer.example',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API key'),
        'TESTPASS123',
      );
      await tester.ensureVisible(find.text('Save indexer'));
      await tester.tap(find.text('Save indexer'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(indexer.value.single.isComplete, isTrue);
    },
  );

  testWidgets('search and settings reflow at 360 pixels with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      _app(
        SearchScreen(
          store: _IndexerStore(),
          searchFn: (_, query, limit, offset) async => SearchManyResultDto(
            page: SearchPageDto(items: [_item('long.' * 10)]),
            failedIndexers: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _search(tester, 'release');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      _app(
        SettingsScreen(
          store: _ProviderStore(),
          indexerStore: _IndexerStore(),
          uiPreferences: UiPreferencesController(UiPreferencesStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
