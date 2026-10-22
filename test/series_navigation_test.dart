import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/player/series_preferences.dart';
import 'package:zanzibarr/player/episode_catalog.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/metadata_enrichment.dart';
import 'package:zanzibarr/metadata/title_details_screen.dart';
import 'package:zanzibarr/metadata/title_library.dart';
import 'package:zanzibarr/search/episode_release_ranker.dart';
import 'package:zanzibarr/search/release_search_selection.dart';
import 'package:zanzibarr/search/search_screen.dart';
import 'package:zanzibarr/settings/series_settings_screen.dart';
import 'package:zanzibarr/settings/indexer_settings.dart';
import 'package:zanzibarr/src/rust/api/search.dart';
import 'metadata_library_test.dart'
    show MemoryStorage, LocalHistory, LocalWatchlist, app, show;

class Episodes extends MetadataService {
  final seasons = <int, List<MediaEpisode>>{
    0: [MediaEpisode(number: 1, title: 'Special', aired: DateTime(2020))],
    1: [
      MediaEpisode(
        number: 1,
        title: 'The arrival',
        aired: DateTime(2020),
        runtimeMinutes: 45,
      ),
      MediaEpisode(
        number: 3,
        title: 'The return',
        aired: DateTime(2020),
        runtimeMinutes: 45,
      ),
    ],
    2: [
      MediaEpisode(
        number: 1,
        title: 'New season',
        aired: DateTime(2021),
        runtimeMinutes: 45,
      ),
    ],
  };
  @override
  Future<MediaTitle?> details(String apiKey, String id) async => show;
  @override
  Future<List<MediaEpisode>> season(
    String apiKey,
    String id,
    int season,
  ) async => seasons[season] ?? [];
}

class NoEnrichment extends MetadataEnrichment {
  @override
  Future<MediaTitle> enrich(MediaTitle title) async => title;
  @override
  Future<List<MediaEpisode>> seasonEpisodes(
    MediaTitle title,
    int season,
    List<MediaEpisode> base,
  ) async => base;
}

class Profiles extends IndexerSettingsStore {
  @override
  Future<List<IndexerProfile>> load() async => const [
    IndexerProfile(
      id: 'source',
      baseUrl: 'https://indexer.example',
      apiKey: 'TESTPASS123',
    ),
  ];
}

class BlockedEnrichmentSettings extends EnrichmentSettingsStore {
  @override
  Future<EnrichmentSettings> load() => Completer<EnrichmentSettings>().future;
}

const target = ReleaseSearchSelection(
  title: 'The Quiet Coast',
  kind: 'tv',
  imdbId: 'tt1234567',
  season: 1,
  episode: 1,
  runtimeMinutes: 45,
  autoPick: true,
);
SearchItemDto release(
  String title, {
  int mb = 1000,
  String? imdbId,
  int? episode,
}) => SearchItemDto(
  title: title,
  nzbUrl: 'https://indexer.example/get/${Uri.encodeComponent(title)}',
  sourceId: 'source',
  sourceIndexer: 'indexer',
  badges: const [],
  mediaKind: 'tv',
  sizeBytes: BigInt.from(mb * 1000000),
  imdbId: imdbId,
  episode: episode,
);

void main() {
  test('NxNN episode ranges and chains cannot be selected as one episode', () {
    for (final episode in ['1x01-02', '1x01-1x02', '1x01 02', '1x01x02']) {
      final item = release('The.Quiet.Coast.$episode.1080p.x264');
      expect(isExactEpisode(item, target), isFalse, reason: episode);
      expect(
        rankEpisodeReleases([item], target, const SeriesOptions()),
        isEmpty,
        reason: episode,
      );
    }
    expect(
      isExactEpisode(release('The.Quiet.Coast.1x01.1080p.x264'), target),
      isTrue,
    );
  });

  testWidgets(
    'closing enrichment cancels settings deadlines without starting requests',
    (tester) async {
      var requests = 0;
      final enrichment = MetadataEnrichment(
        settings: BlockedEnrichmentSettings(),
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final pending = enrichment.enrich(show);
      enrichment.close();
      await pending;
      await tester.pump();
      expect(requests, 0);
    },
  );
  testWidgets('cancelled episode search cannot later download or play', (
    tester,
  ) async {
    final result = Completer<SearchManyResultDto>();
    var downloads = 0, plays = 0;
    await tester.pumpWidget(
      app(
        SearchScreen(
          store: Profiles(),
          initialSelection: target,
          autoSearchInitialSelection: true,
          capsFn: (_) async => const IndexerCapsDto(
            searchAvailable: true,
            tvSearchAvailable: true,
            movieSearchAvailable: false,
          ),
          searchFn: (_, _, _, _) => result.future,
          downloadFn: (_, _, _) async {
            downloads++;
            return '/test/unused.nzb';
          },
          onDownloaded: (_) => plays++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(app(const SizedBox()));
    result.complete(
      SearchManyResultDto(
        page: SearchPageDto(
          items: [release('The.Quiet.Coast.S01E01.1080p.x264')],
        ),
        failedIndexers: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(downloads, 0);
    expect(plays, 0);
  });
  testWidgets('uncertain automatic choice stays manual without downloading', (
    tester,
  ) async {
    final prefs = SeriesPreferences(storage: MemoryStorage());
    await prefs.load();
    await prefs.save(prefs.value.copyWith(autoSelect: true));
    var downloads = 0;
    await tester.pumpWidget(
      app(
        SearchScreen(
          store: Profiles(),
          seriesPreferences: prefs,
          initialSelection: const ReleaseSearchSelection(
            title: 'The Quiet Coast',
            kind: 'tv',
            imdbId: 'tt1234567',
            season: 1,
            episode: 1,
            autoPick: true,
          ),
          autoSearchInitialSelection: true,
          capsFn: (_) async => const IndexerCapsDto(
            searchAvailable: true,
            tvSearchAvailable: true,
            movieSearchAvailable: false,
          ),
          searchFn: (_, _, _, _) async => SearchManyResultDto(
            page: SearchPageDto(
              items: [release('The.Quiet.Coast.S01E01.1080p.x264')],
            ),
            failedIndexers: const [],
          ),
          downloadFn: (_, _, _) async {
            downloads++;
            return '/test/unused.nzb';
          },
          onDownloaded: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(downloads, 0);
    expect(
      find.textContaining('No confident automatic choice'),
      findsOneWidget,
    );
  });
  test(
    'series preferences preserve defaults and choices across reloads',
    () async {
      final storage = MemoryStorage();
      final prefs = SeriesPreferences(storage: storage);
      await prefs.load();
      expect(prefs.value.showTitles, isTrue);
      expect(prefs.value.showSynopsis, isFalse);
      expect(prefs.value.autoSelect, isFalse);
      await prefs.save(
        prefs.value.copyWith(
          autoSelect: true,
          connectionMbps: 50,
          showStills: false,
        ),
      );
      final restored = SeriesPreferences(storage: storage);
      await restored.load();
      expect(restored.value.autoSelect, isTrue);
      expect(restored.value.connectionMbps, 50);
      expect(restored.value.showStills, isFalse);
      storage.failWrite = true;
      expect(
        await restored.save(restored.value.copyWith(connectionMbps: 100)),
        isFalse,
      );
      expect(restored.value.connectionMbps, 50);
      expect(restored.error, isNotNull);
    },
  );
  test(
    'damaged preferences cannot silently enable auto playback or be overwritten',
    () async {
      final storage = MemoryStorage()
        ..values['player.series.v1'] = '{"autoSelect":"yes"}';
      final prefs = SeriesPreferences(storage: storage);
      await prefs.load();
      expect(prefs.ready, isFalse);
      expect(prefs.value.autoSelect, isFalse);
      expect(await prefs.save(const SeriesOptions(autoSelect: true)), isFalse);
    },
  );
  test('ranking uses connection headroom and resolution, not largest file', () {
    final small = release('The.Quiet.Coast.S01E01.720p.x264', mb: 500);
    final good = release('The.Quiet.Coast.S01E01.1080p.x264', mb: 2000);
    final huge = release('The.Quiet.Coast.S01E01.1080p.x264', mb: 9000);
    final list = [huge, small, good];
    expect(
      rankEpisodeReleases(list, target, const SeriesOptions()).first.item,
      good,
    );
    expect(
      rankEpisodeReleases(
        list,
        target,
        const SeriesOptions(connectionMbps: 5),
      ).first.item,
      small,
    );
    expect(
      rankEpisodeReleases(
        list,
        target,
        const SeriesOptions(maxHeight: 720),
      ).single.item,
      small,
    );
  });
  for (final name in [
    'Other.Show.S01E01.1080p.x264',
    'The.Quiet.Coast.S01E02.1080p.x264',
    'The.Quiet.Coast.S01.1080p.x264',
    'The.Quiet.Coast.S01E01E02.1080p.x264',
    'The.Quiet.Coast.S01E01-E03.1080p.x264',
    'The.Quiet.Coast.S01E01.Sample.1080p.x264',
    'The.Quiet.Coast.S01E01.1080p.AV1',
    'The.Quiet.Coast.S01E01.2160p.DV.x264',
  ]) {
    test('no automatic choice for $name', () {
      expect(
        rankEpisodeReleases([release(name)], target, const SeriesOptions()),
        isEmpty,
      );
    });
  }
  test(
    'conflicting IDs/episode fields and unknown runtimes do not auto pick',
    () {
      expect(
        isExactEpisode(
          release('The.Quiet.Coast.S01E01.1080p.x264', imdbId: 'tt9999999'),
          target,
        ),
        isFalse,
      );
      expect(
        isExactEpisode(
          release('The.Quiet.Coast.S01E01.1080p.x264', episode: 2),
          target,
        ),
        isFalse,
      );
      expect(
        rankEpisodeReleases(
          [release('The.Quiet.Coast.S01E01.1080p.x264')],
          const ReleaseSearchSelection(
            title: 'The Quiet Coast',
            kind: 'tv',
            season: 1,
            episode: 1,
          ),
          const SeriesOptions(),
        ),
        isEmpty,
      );
    },
  );
  test(
    'catalog navigation honours gaps, season boundaries and specials',
    () async {
      final service = Episodes();
      final enrichment = NoEnrichment();
      addTearDown(service.close);
      addTearDown(enrichment.close);
      final catalog = EpisodeCatalog(
        service: service,
        enrichment: enrichment,
        apiKey: 'TESTPASS123',
      );
      final next = await catalog.adjacent(show.imdbId, 1, 1, 1, autoPick: true);
      expect(next.episode, 3);
      expect(next.runtimeMinutes, 45);
      final cross = await catalog.adjacent(
        show.imdbId,
        1,
        3,
        1,
        autoPick: true,
      );
      expect(cross.season, 2);
      expect(cross.episode, 1);
      final previous = await catalog.adjacent(
        show.imdbId,
        2,
        1,
        -1,
        autoPick: false,
      );
      expect(previous.season, 1);
      expect(previous.episode, 3);
      await expectLater(
        catalog.adjacent(show.imdbId, 0, 1, 1, autoPick: true),
        throwsA(isA<EpisodeNavigationException>()),
      );
      await expectLater(
        catalog.adjacent(show.imdbId, 1, 2, 1, autoPick: true),
        throwsA(isA<EpisodeNavigationException>()),
      );
      service.seasons[2] = [
        MediaEpisode(number: 1, title: 'Future', aired: DateTime(2200)),
      ];
      await expectLater(
        catalog.adjacent(show.imdbId, 1, 3, 1, autoPick: true),
        throwsA(isA<EpisodeNavigationException>()),
      );
    },
  );
  test(
    'season stills/runtime use verified identity, bounded season fetch and cache',
    () async {
      final storage = MemoryStorage();
      final settings = EnrichmentSettingsStore(storage: storage);
      await settings.save(const EnrichmentSettings(tmdbToken: 'TESTPASS123'));
      final calls = <String>[];
      final enrichment = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: MockClient((r) async {
          calls.add(r.url.path);
          expect(r.headers['Authorization'], 'Bearer TESTPASS123');
          final Object data = switch (r.url.path) {
            '/3/find/tt1234567' => {
              'tv_results': [
                {'id': 42},
              ],
            },
            '/3/tv/42' => {
              'id': 42,
              'external_ids': {'imdb_id': show.imdbId},
            },
            '/3/tv/42/season/1' => {
              'season_number': 1,
              'episodes': [
                {
                  'episode_number': 1,
                  'season_number': 1,
                  'show_id': 42,
                  'name': 'Arrival',
                  'air_date': '2020-01-01',
                  'runtime': 45,
                  'still_path': '/still.jpg',
                  'overview': 'Hidden plot',
                },
                {
                  'episode_number': 2,
                  'season_number': 1,
                  'show_id': 999,
                  'name': 'Wrong show',
                  'still_path': '/bad.jpg',
                },
              ],
            },
            _ => <String, Object>{},
          };
          return http.Response(jsonEncode(data), 200);
        }),
      );
      addTearDown(enrichment.close);
      final rows = await enrichment.seasonEpisodes(show, 1, const []);
      expect(rows.single.runtimeMinutes, 45);
      expect(rows.single.still, 'https://image.tmdb.org/t/p/w500/still.jpg');
      await enrichment.seasonEpisodes(show, 1, const []);
      expect(calls.length, 3);
    },
  );
  for (final width in [390.0, 1100.0]) {
    testWidgets('episode names, graphics and settings at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = MemoryStorage();
      final prefs = SeriesPreferences(storage: storage);
      await prefs.load();
      final catalog = Episodes();
      final enrichment = NoEnrichment();
      addTearDown(catalog.close);
      addTearDown(enrichment.close);
      await tester.pumpWidget(
        app(
          TitleDetailsScreen(
            title: show,
            service: catalog,
            apiKey: 'TESTPASS123',
            seriesPreferences: prefs,
            enrichment: enrichment,
            libraryStore: TitleLibraryStore(storage: storage),
            historyStore: LocalHistory(),
            watchlistStore: LocalWatchlist(),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('The arrival'));
      await tester.pumpAndSettle();
      expect(find.text('The arrival'), findsOneWidget);
      expect(find.text('Show episode titles (spoilers)'), findsNothing);
      expect(tester.takeException(), isNull);
      await prefs.save(prefs.value.copyWith(showTitles: false));
      await tester.pumpAndSettle();
      expect(find.text('The arrival'), findsNothing);
      expect(find.text('Episode 1'), findsOneWidget);
    });
  }
  testWidgets(
    'saved auto choice goes from episode search to selected NZB once',
    (tester) async {
      final prefs = SeriesPreferences(storage: MemoryStorage());
      await prefs.load();
      await prefs.save(prefs.value.copyWith(autoSelect: true));
      final downloads = <String>[];
      await tester.pumpWidget(
        app(
          SearchScreen(
            store: Profiles(),
            seriesPreferences: prefs,
            initialSelection: target,
            autoSearchInitialSelection: true,
            capsFn: (_) async => const IndexerCapsDto(
              searchAvailable: true,
              tvSearchAvailable: true,
              movieSearchAvailable: false,
              tvSearchParams: ['imdbid', 'season', 'ep'],
            ),
            searchFn: (_, _, _, _) async => SearchManyResultDto(
              page: SearchPageDto(
                items: [
                  release('The.Quiet.Coast.S01E01.720p.x264', mb: 500),
                  release('The.Quiet.Coast.S01E01.1080p.x264'),
                ],
              ),
              failedIndexers: const [],
            ),
            downloadFn: (_, _, name) async {
              downloads.add(name);
              return '/test/episode.nzb';
            },
            onDownloaded: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(downloads, ['The.Quiet.Coast.S01E01.1080p.x264']);
      expect(find.byKey(const Key('episode-auto-status')), findsOneWidget);
    },
  );
  testWidgets('settings expose independent names, stills and plot controls', (
    tester,
  ) async {
    final prefs = SeriesPreferences(storage: MemoryStorage());
    await prefs.load();
    await tester.pumpWidget(app(SeriesSettingsScreen(preferences: prefs)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show episode names'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Show episode names'));
    await tester.pumpAndSettle();
    expect(prefs.value.showTitles, isFalse);
    expect(prefs.value.showSynopsis, isFalse);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('render episode navigation at $width', (tester) async {
      if (Platform.environment['CAPTURE_SERIES_UI'] != '1') return;
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await (FontLoader(
        'Noto Sans',
      )..addFont(rootBundle.load('assets/fonts/subtitle.ttf'))).load();
      var dir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8; i++) {
        final icons = File(
          '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (icons.existsSync()) {
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync())),
              ))
              .load();
          break;
        }
        dir = dir.parent;
      }
      final storage = MemoryStorage();
      final prefs = SeriesPreferences(storage: storage);
      await prefs.load();
      await prefs.save(prefs.value.copyWith(autoSelect: true));
      final catalog = Episodes();
      final enrichment = NoEnrichment();
      addTearDown(catalog.close);
      addTearDown(enrichment.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('series-capture'),
          child: app(
            TitleDetailsScreen(
              title: show,
              service: catalog,
              enrichment: enrichment,
              seriesPreferences: prefs,
              apiKey: 'TESTPASS123',
              historyStore: LocalHistory(),
              watchlistStore: LocalWatchlist(),
              libraryStore: TitleLibraryStore(storage: storage),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Seasons & episodes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('series-capture')),
        );
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'dist/audit/series-episodes-${width.toInt()}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
