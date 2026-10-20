import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/l10n/app_localizations.dart';
import 'package:zanzibarr/search/search_screen.dart';
import 'package:zanzibarr/settings/indexer_settings.dart';
import 'package:zanzibarr/src/rust/api/search.dart';

import 'l10n_test_helper.dart';

/// Gerçek secure storage yerine sabit profiller döndüren sahte depo.
class _FakeIndexerStore extends IndexerSettingsStore {
  _FakeIndexerStore(this.profiles);

  List<IndexerProfile> profiles;
  bool failLoad = false;

  @override
  Future<List<IndexerProfile>> load() async {
    if (failLoad) throw const FormatException('Stored profiles unreadable');
    return profiles;
  }

  @override
  Future<void> save(List<IndexerProfile> value) async => profiles = value;
}

final _completeStore = _FakeIndexerStore(const [
  IndexerProfile(
    id: '1',
    baseUrl: 'https://indexer.example',
    apiKey: 'anahtar',
  ),
]);

SearchItemDto _movieItem() => SearchItemDto(
  title: 'Bir.Film.2024.2160p.WEB-DL.DV.HEVC-GRP',
  nzbUrl: 'https://indexer.example/getnzb/1',
  sizeBytes: BigInt.from(6979321856), // 6,5 GB
  publishedEpochSecs:
      DateTime.now()
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch ~/
      1000,
  badges: const ['2160p', 'HEVC', 'DV'],
  mediaKind: 'movie',
  year: 2024,
  sourceIndexer: 'https://indexer.example',
);

SearchItemDto _tvItem() => SearchItemDto(
  title: 'Bir.Dizi.S01E02.1080p.WEB-GRP',
  nzbUrl: 'https://indexer.example/getnzb/2',
  sizeBytes: BigInt.from(734003200), // 700 MB
  badges: const ['1080p'],
  mediaKind: 'tv',
  season: 1,
  episode: 2,
  sourceIndexer: 'https://indexer.example',
);

/// Sabit iki sonuç döndüren sahte arama; tüm verilen config'leri yanıtlar
/// (çoğu testte tek config olsa da fan-out imzasını birebir taklit eder).
Future<SearchManyResultDto> _fakeSearch(
  List<IndexerConfigDto> configs,
  String query,
  int limit,
  int offset,
) async => SearchManyResultDto(
  page: SearchPageDto(total: BigInt.from(2), items: [_movieItem(), _tvItem()]),
  failedIndexers: const [],
);

Future<void> _enterQueryAndSearch(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.tap(find.widgetWithIcon(IconButton, Icons.search_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'adult search retains category after query edits and avoids mainstream matching',
    (tester) async {
      final configsSeen = <List<IndexerConfigDto>>[];
      await tester.pumpWithL10n(
        SearchScreen(
          adultOnly: true,
          store: _completeStore,
          searchFn: (configs, query, limit, offset) async {
            configsSeen.add(configs);
            return _fakeSearch(configs, query, limit, offset);
          },
          capsFn: (_) async =>
              throw StateError('Adult text search must not request movie caps'),
        ),
      );
      await tester.pumpAndSettle();
      await _enterQueryAndSearch(tester, 'Catalog fixture');
      await _enterQueryAndSearch(tester, 'Edited fixture');
      expect(configsSeen, hasLength(2));
      for (final configs in configsSeen) {
        expect(configs.single.structured!.kind, 'adult');
        expect(configs.single.structured!.imdbId, isNull);
      }
      expect(find.byIcon(Icons.movie_filter_outlined), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    },
  );
  testWidgets('unreadable profiles show a recoverable load failure', (
    tester,
  ) async {
    final store = _FakeIndexerStore(_completeStore.profiles)..failLoad = true;
    var calls = 0;
    await tester.pumpWithL10n(
      SearchScreen(
        store: store,
        searchFn: (configs, query, limit, offset) async {
          calls++;
          return _fakeSearch(configs, query, limit, offset);
        },
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(SearchScreen)));
    expect(find.text(l.settingsLoadHint), findsOneWidget);
    await _enterQueryAndSearch(tester, 'film');
    expect(calls, 0);
    store.failLoad = false;
    await tester.tap(find.text(l.retry));
    await tester.pumpAndSettle();
    await _enterQueryAndSearch(tester, 'film');
    expect(calls, 1);
  });
  testWidgets(
    'confirmed identity follows capabilities and clears when query changes',
    (tester) async {
      final calls = <List<IndexerConfigDto>>[];
      final queries = <String>[];
      var capsCalls = 0;
      await tester.pumpWithL10n(
        SearchScreen(
          store: _FakeIndexerStore([
            ..._completeStore.profiles,
            const IndexerProfile(
              id: 'offline',
              baseUrl: 'https://offline.example',
              apiKey: 'TESTPASS123',
            ),
          ]),
          capsFn: (config) async {
            capsCalls++;
            if (config.id == 'offline') throw StateError('offline');
            return const IndexerCapsDto(
              searchAvailable: true,
              movieSearchAvailable: true,
              tvSearchAvailable: false,
              movieSearchParams: ['imdbid'],
            );
          },
          searchFn: (configs, query, limit, offset) async {
            calls.add(configs);
            queries.add(query);
            return SearchManyResultDto(
              page: SearchPageDto(
                items: calls.length == 1 ? [_movieItem()] : const [],
              ),
              failedIndexers: const [],
              hasMore: calls.length == 1,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(capsCalls, 0);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'The Matrix');
      await tester.enterText(find.byType(TextFormField).at(1), 'tt0133093');
      await tester.enterText(find.byType(TextFormField).at(2), '1999');
      await tester.tap(find.text('Sürümleri bul'));
      await tester.pumpAndSettle();
      expect(capsCalls, 2);
      expect(calls.single.first.structured!.imdbId, 'tt0133093');
      expect(calls.single.first.structured!.supportedParams, ['imdbid']);
      expect(calls.single.last.structured!.supportedParams, isEmpty);
      expect(queries.single, 'The Matrix 1999');
      await tester.tap(find.text('Daha fazla sonuç yükle'));
      await tester.pumpAndSettle();
      expect(calls.last.first.structured!.imdbId, 'tt0133093');
      expect(queries.last, 'The Matrix 1999');
      await _enterQueryAndSearch(tester, 'A different film');
      expect(calls.last.every((config) => config.structured == null), isTrue);
      expect(capsCalls, 2);
    },
  );

  testWidgets('search toggles persist and invalidate a pending response', (
    tester,
  ) async {
    final store = _FakeIndexerStore(const [
      IndexerProfile(
        id: 'a',
        nickname: 'Primary',
        baseUrl: 'https://a.example',
        apiKey: 'TESTPASS123',
      ),
      IndexerProfile(
        id: 'b',
        nickname: 'Secondary',
        baseUrl: 'https://b.example',
        apiKey: 'TESTPASS123',
      ),
    ]);
    final pending = Completer<SearchManyResultDto>();
    final sources = <List<String?>>[];
    await tester.pumpWithL10n(
      SearchScreen(
        store: store,
        searchFn: (configs, query, limit, offset) {
          sources.add(configs.map((c) => c.id).toList());
          return sources.length == 1
              ? pending.future
              : Future.value(
                  SearchManyResultDto(
                    page: SearchPageDto(items: const []),
                    failedIndexers: const [],
                  ),
                );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'film');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<int>, 'Secondary'),
    );
    await tester.pumpAndSettle();
    pending.complete(
      SearchManyResultDto(
        page: SearchPageDto(items: [_movieItem()]),
        failedIndexers: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_movieItem().title), findsNothing);
    expect(store.profiles.last.enabled, isFalse);
    await _enterQueryAndSearch(tester, 'film');
    expect(sources, [
      ['a', 'b'],
      ['a'],
    ]);
  });
  testWidgets(
    'duplicate display names download using stable profile identity',
    (tester) async {
      final store = _FakeIndexerStore(const [
        IndexerProfile(
          id: 'a',
          nickname: 'Shared',
          baseUrl: 'https://a.example',
          apiKey: 'TESTPASS123',
        ),
        IndexerProfile(
          id: 'b',
          nickname: 'Shared',
          baseUrl: 'https://b.example',
          apiKey: 'TESTPASS123',
        ),
      ]);
      String? source;
      await tester.pumpWithL10n(
        SearchScreen(
          store: store,
          searchFn: (configs, query, limit, offset) async =>
              SearchManyResultDto(
                page: SearchPageDto(
                  items: [
                    SearchItemDto(
                      title: 'From second',
                      nzbUrl: 'https://b.example/nzb',
                      badges: const [],
                      mediaKind: 'movie',
                      sourceIndexer: 'Shared',
                      sourceId: 'b',
                    ),
                  ],
                ),
                failedIndexers: const [],
              ),
          downloadFn: (config, url, name) async {
            source = config.id;
            return '/tmp/test.nzb';
          },
          onDownloaded: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      await _enterQueryAndSearch(tester, 'film');
      await tester.tap(find.text('From second'));
      await tester.pumpAndSettle();
      expect(source, 'b');
    },
  );

  testWidgets('all failed indexers show retry instead of no results', (
    tester,
  ) async {
    await tester.pumpWithL10n(
      SearchScreen(
        store: _completeStore,
        searchFn: (_, query, limit, offset) async => SearchManyResultDto(
          page: SearchPageDto(items: const []),
          failedIndexers: const ['Unavailable'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _enterQueryAndSearch(tester, 'film');
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.text('Sonuç bulunamadı'), findsNothing);
  });
  testWidgets('Arama sonuçları rozet, boyut, yaş ve toplam ile listeleniyor', (
    tester,
  ) async {
    await tester.pumpWithL10n(
      SearchScreen(store: _completeStore, searchFn: _fakeSearch),
    );
    await tester.pumpAndSettle();

    // Henüz arama yapılmadan ipucu görünür.
    expect(
      find.text("Indexer'ınızda aramak için bir sürüm adı yazın."),
      findsOneWidget,
    );

    await _enterQueryAndSearch(tester, 'film');

    expect(find.text('Bir.Film.2024.2160p.WEB-DL.DV.HEVC-GRP'), findsOneWidget);
    expect(find.text('Bir.Dizi.S01E02.1080p.WEB-GRP'), findsOneWidget);
    expect(find.text('2160p'), findsOneWidget);
    expect(find.text('HEVC'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('6.5 GB'), findsOneWidget);
    expect(find.text('700 MB'), findsOneWidget);
    expect(find.text('10 g'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('2 sonuç'), findsOneWidget);
  });

  testWidgets(
    'Öğeye dokununca downloadFn çağrılır ve onDownloaded tetiklenir',
    (tester) async {
      IndexerConfigDto? usedConfig;
      String? usedUrl;
      String? usedName;
      String? downloadedPath;
      await tester.pumpWithL10n(
        SearchScreen(
          store: _completeStore,
          searchFn: _fakeSearch,
          downloadFn: (config, nzbUrl, suggestedName) async {
            usedConfig = config;
            usedUrl = nzbUrl;
            usedName = suggestedName;
            return '/tmp/indirilen.nzb';
          },
          onDownloaded: (path) => downloadedPath = path,
        ),
      );
      await tester.pumpAndSettle();
      await _enterQueryAndSearch(tester, 'film');

      await tester.tap(find.text('Bir.Film.2024.2160p.WEB-DL.DV.HEVC-GRP'));
      await tester.pumpAndSettle();

      expect(usedConfig?.baseUrl, 'https://indexer.example');
      expect(usedConfig?.apiKey, 'anahtar');
      expect(usedUrl, 'https://indexer.example/getnzb/1');
      expect(usedName, 'Bir.Film.2024.2160p.WEB-DL.DV.HEVC-GRP');
      expect(downloadedPath, '/tmp/indirilen.nzb');
    },
  );

  testWidgets('İndirme hatası SnackBar ile gösterilir', (tester) async {
    await tester.pumpWithL10n(
      SearchScreen(
        store: _completeStore,
        searchFn: _fakeSearch,
        downloadFn: (config, nzbUrl, suggestedName) async =>
            throw Exception('disk dolu'),
        onDownloaded: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    await _enterQueryAndSearch(tester, 'film');

    await tester.tap(find.text('Bir.Dizi.S01E02.1080p.WEB-GRP'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'NZB indirilemedi. Bağlantınızı ve indexer ayarlarını kontrol edip yeniden deneyin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Arama hatası yeniden deneme görünümüne düşer', (tester) async {
    await tester.pumpWithL10n(
      SearchScreen(
        store: _completeStore,
        searchFn: (configs, query, limit, offset) async =>
            throw Exception('Indexer yanıt vermiyor'),
      ),
    );
    await tester.pumpAndSettle();
    await _enterQueryAndSearch(tester, 'film');

    expect(
      find.text(
        'Arama başarısız. İnternet bağlantınızı ve indexer ayarlarını kontrol edip yeniden deneyin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Yeniden dene'), findsOneWidget);
  });

  testWidgets('Sonuç yoksa bilgi görünümü gösterilir', (tester) async {
    await tester.pumpWithL10n(
      SearchScreen(
        store: _completeStore,
        searchFn: (configs, query, limit, offset) async => SearchManyResultDto(
          page: SearchPageDto(total: BigInt.zero, items: const []),
          failedIndexers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _enterQueryAndSearch(tester, 'olmayan');

    expect(find.text('Sonuç bulunamadı'), findsOneWidget);
  });

  testWidgets('Indexer ayarları eksikse ayarlara yönlendirme gösterilir', (
    tester,
  ) async {
    await tester.pumpWithL10n(SearchScreen(store: _FakeIndexerStore(const [])));
    await tester.pumpAndSettle();

    expect(
      find.text("Önce ayarlardan indexer URL'sini ve API anahtarını girin."),
      findsOneWidget,
    );
    expect(find.text('Ayarlara git'), findsOneWidget);
  });

  testWidgets(
    'Bazı indexer\'lar yanıt vermezse kısmi başarısızlık uyarısı görünür',
    (tester) async {
      await tester.pumpWithL10n(
        SearchScreen(
          store: _completeStore,
          searchFn: (configs, query, limit, offset) async =>
              SearchManyResultDto(
                page: SearchPageDto(total: BigInt.one, items: [_movieItem()]),
                failedIndexers: const ['DeadIndexer'],
              ),
        ),
      );
      await tester.pumpAndSettle();
      await _enterQueryAndSearch(tester, 'film');

      expect(
        find.text(
          "1 indexer'dan 1 tanesi yanıt vermedi; kalanların sonuçları gösteriliyor.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Sonuç kartında kaynak indexer rozeti görünür', (tester) async {
    await tester.pumpWithL10n(
      SearchScreen(store: _completeStore, searchFn: _fakeSearch),
    );
    await tester.pumpAndSettle();
    await _enterQueryAndSearch(tester, 'film');

    expect(find.text('https://indexer.example'), findsWidgets);
  });
}
