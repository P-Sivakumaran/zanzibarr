import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:zanzibarr/chat/suggestion_metadata.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'package:zanzibarr/metadata/metadata_enrichment.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/title_information.dart';
import 'package:zanzibarr/metadata/artwork.dart';
import 'package:zanzibarr/metadata/title_details_screen.dart';
import 'package:zanzibarr/metadata/title_library.dart';
import 'package:zanzibarr/settings/enrichment_settings.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'metadata_library_test.dart'
    show MemoryStorage, LocalWatchlist, LocalHistory, FixtureArt, app;
import 'automatic_metadata_test.dart' show Settings;

const film = MediaTitle(
  imdbId: 'tt1049413',
  title: 'Up',
  year: '2009',
  kind: 'movie',
  actors: 'Actor One, Actor Two',
  ratings: {'Rotten Tomatoes': '95%', 'Metacritic': '82/100'},
  country: 'United States',
);
http.Response json(
  Object data, {
  int status = 200,
  Map<String, String>? headers,
}) => http.Response(jsonEncode(data), status, headers: headers ?? const {});
Map<String, dynamic> details({String imdb = 'tt1049413'}) => {
  'id': 141,
  'external_ids': {'imdb_id': imdb},
  'credits': {
    'cast': [
      {
        'name': 'Actor One',
        'character': 'Explorer',
        'profile_path': '/actor.jpg',
      },
    ],
  },
  'keywords': {
    'keywords': [
      {'name': 'friendship'},
    ],
  },
};

class ReviewCatalog extends MetadataService {
  ReviewCatalog(this.value);
  final MediaTitle value;
  @override
  Future<MediaTitle?> details(String apiKey, String id) async => value;
}

class IdentityCatalog extends MetadataService {
  int searches = 0;
  final ids = <String>[];
  @override
  Future<MetadataPage> search(
    String apiKey,
    String query, {
    String? kind,
    int page = 1,
    int? year,
  }) async {
    searches++;
    return const MetadataPage([]);
  }

  @override
  Future<MediaTitle?> details(String apiKey, String id) async {
    ids.add(id);
    return MediaTitle(
      imdbId: id,
      title: 'Correct $id',
      year: '2009',
      kind: 'movie',
    );
  }
}

void main() {
  testWidgets(
    'additional source settings preserve unsaved drafts and save independently',
    (tester) async {
      final storage = MemoryStorage();
      final settings = EnrichmentSettingsStore(storage: storage);
      await tester.pumpWidget(
        app(
          EnrichmentSettingsScreen(
            store: settings,
            integrations: IntegrationStore(storage: storage),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'TESTPASS123');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard metadata changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'TESTPASS123',
      );
      await tester.ensureVisible(find.text('Save additional sources'));
      await tester.tap(find.text('Save additional sources'));
      await tester.pumpAndSettle();
      expect((await settings.load()).tmdbToken, 'TESTPASS123');
    },
  );
  testWidgets(
    'rich title page and source settings preview at desktop and narrow widths',
    (tester) async {
      const screenshots = bool.fromEnvironment('UPDATE_ENRICHMENT_SCREENSHOTS');
      final font = FontLoader('Noto Sans')
        ..addFont(rootBundle.load('assets/fonts/subtitle.ttf'));
      await font.load();
      var directory = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8; i++) {
        final candidate = File(
          '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (candidate.existsSync()) {
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(ByteData.sublistView(candidate.readAsBytesSync())),
            );
          await icons.load();
          break;
        }
        directory = directory.parent;
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loaded = await tester.runAsync(
        () => File('test/fixtures/figma/quiet-coast.png').readAsBytes(),
      );
      final art = FixtureArt(loaded!);
      final media = MediaTitle.fromJson({
        ...film.toJson(),
        'Title': 'The Quiet Coast',
        'Year': '2026',
        'Plot':
            'A coastal mystery brings an investigator back to a town full of unfinished stories.',
        'Poster': 'https://m.media-amazon.com/coast.jpg',
        'Director': 'Alex Morgan',
        'Writer': 'Sam Rivera',
        'Awards': 'Festival selection',
        'Released': '19 Oct 2026',
        'cast': [
          for (final name in [
            'Alex Ellis',
            'Jamie Reed',
            'Morgan Vale',
            'Riley Hart',
          ])
            {'name': name, 'character': 'Ensemble cast'},
        ],
        'topics': ['belonging', 'family', 'coastal mystery'],
        'filmingLocations': ['Coastal studio'],
        'narrativeLocations': ['Fictional coastal town'],
        'enrichmentSources': ['TMDB', 'Wikidata'],
      });
      final catalog = ReviewCatalog(media);
      for (final width in [1440, 360]) {
        tester.view.physicalSize = Size(width.toDouble(), 1200);
        final storage = MemoryStorage();
        final enrichment = MetadataEnrichment(
          storage: storage,
          settings: EnrichmentSettingsStore(storage: storage),
        );
        await tester.pumpWidget(
          app(
            RepaintBoundary(
              key: const Key('rich-preview'),
              child: TitleDetailsScreen(
                title: media,
                service: catalog,
                apiKey: 'TESTPASS123',
                enrichment: enrichment,
                artworkLoader: art,
                libraryStore: TitleLibraryStore(storage: storage),
                watchlistStore: LocalWatchlist(),
                historyStore: LocalHistory(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => precacheImage(
            ResizeImage(MemoryImage(loaded), width: 500),
            tester.element(find.byType(TitleArtwork).first),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alex Ellis'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (screenshots) {
          await expectLater(
            find.byKey(const Key('rich-preview')),
            matchesGoldenFile(
              '../docs/screenshots/enrichment-title-$width-flutter.png',
            ),
          );
        }
        await tester.pumpWidget(const SizedBox());
        enrichment.close();
      }
      final storage = MemoryStorage();
      tester.view.physicalSize = const Size(1280, 1200);
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const Key('source-preview'),
            child: EnrichmentSettingsScreen(
              store: EnrichmentSettingsStore(storage: storage),
              integrations: IntegrationStore(storage: storage),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (screenshots) {
        await expectLater(
          find.byKey(const Key('source-preview')),
          matchesGoldenFile(
            '../docs/screenshots/enrichment-settings-flutter.png',
          ),
        );
      }
      catalog.close();
      art.close();
    },
  );
  test(
    'optional enrichment sends nothing before sources are configured',
    () async {
      final storage = MemoryStorage();
      var calls = 0;
      final service = MetadataEnrichment(
        storage: storage,
        settings: EnrichmentSettingsStore(storage: storage),
        client: MockClient((_) async {
          calls++;
          return json({});
        }),
      );
      final result = await service.enrich(film);
      expect(result.title, film.title);
      expect(calls, 0);
      service.close();
    },
  );
  test(
    'TMDB resolves by trusted ID, retains source facts, persists snapshots and mappings',
    () async {
      final storage = MemoryStorage();
      final settings = EnrichmentSettingsStore(storage: storage);
      await settings.save(const EnrichmentSettings(tmdbToken: 'TESTPASS123'));
      var time = DateTime.utc(2026, 10, 19), finds = 0, detailCalls = 0;
      http.Client client() => MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer TESTPASS123');
        if (req.url.path.contains('/find/')) {
          finds++;
          return json({
            'movie_results': [
              {'id': 141},
            ],
          });
        }
        detailCalls++;
        expect(
          req.url.queryParameters['append_to_response'],
          contains('credits'),
        );
        return json(details());
      });
      var service = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: client(),
        now: () => time,
      );
      var result = await service.enrich(film);
      expect(result.cast.single.character, 'Explorer');
      expect(result.topics, ['friendship']);
      expect(result.country, film.country);
      expect(
        result.cast.single.photo,
        'https://image.tmdb.org/t/p/w185/actor.jpg',
      );
      expect(result.enrichmentSources, ['TMDB']);
      expect(finds, 1);
      expect(detailCalls, 1);
      expect(
        storage.values['metadata.enrichment.cache.v1'],
        isNot(contains('TESTPASS123')),
      );
      service.close();
      service = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: client(),
        now: () => time,
      );
      result = await service.enrich(film);
      expect(result.cast.single.name, 'Actor One');
      expect(finds, 1);
      expect(detailCalls, 1);
      time = time.add(const Duration(days: 8));
      await service.enrich(film);
      expect(finds, 1);
      expect(detailCalls, 2);
      service.close();
    },
  );
  test(
    'wrong TMDB identity is rejected; missing mapping is negatively cached across reopening',
    () async {
      for (final missing in [false, true]) {
        final storage = MemoryStorage();
        final settings = EnrichmentSettingsStore(storage: storage);
        await settings.save(const EnrichmentSettings(tmdbToken: 'TESTPASS123'));
        var calls = 0;
        http.Client client() => MockClient((req) async {
          calls++;
          return json(
            req.url.path.contains('/find/')
                ? {
                    'movie_results': missing
                        ? []
                        : [
                            {'id': 141},
                          ],
                  }
                : details(imdb: 'tt9999999'),
          );
        });
        var service = MetadataEnrichment(
          storage: storage,
          settings: settings,
          client: client(),
        );
        expect((await service.enrich(film)).cast, isEmpty);
        service.close();
        final before = calls;
        service = MetadataEnrichment(
          storage: storage,
          settings: settings,
          client: client(),
        );
        expect((await service.enrich(film)).cast, isEmpty);
        expect(calls, before);
        service.close();
      }
    },
  );
  test(
    'provider Retry-After survives restarts and delays further requests',
    () async {
      final storage = MemoryStorage();
      final settings = EnrichmentSettingsStore(storage: storage);
      await settings.save(const EnrichmentSettings(tmdbToken: 'TESTPASS123'));
      var calls = 0;
      var time = DateTime.utc(2026, 10, 19);
      http.Client client() => MockClient((_) async {
        calls++;
        return json({}, status: 429, headers: {'retry-after': '3600'});
      });
      var service = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: client(),
        now: () => time,
      );
      await service.enrich(film);
      service.close();
      service = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: client(),
        now: () => time,
      );
      time = time.add(const Duration(minutes: 30));
      await service.enrich(film);
      expect(calls, 1);
      time = time.add(const Duration(minutes: 31));
      await service.enrich(film);
      expect(calls, 2);
      service.close();
    },
  );
  test(
    'Wikidata keeps filming places separate from story setting and origin',
    () async {
      final storage = MemoryStorage();
      final settings = EnrichmentSettingsStore(storage: storage);
      await settings.save(const EnrichmentSettings(locations: true));
      final service = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: MockClient((req) async {
          expect(req.headers['Authorization'], isNull);
          expect(req.url.queryParameters['query'], contains('tt1049413'));
          return json({
            'results': {
              'bindings': [
                for (final p in ['P915', 'P840'])
                  {
                    'item': {'value': 'http://www.wikidata.org/entity/Q123'},
                    'property': {
                      'value': 'http://www.wikidata.org/prop/direct/$p',
                    },
                    'placeLabel': {
                      'value': p == 'P915' ? 'Studio' : 'Fantasy land',
                    },
                  },
              ],
            },
          });
        }),
      );
      final result = await service.enrich(film);
      expect(result.filmingLocations, ['Studio']);
      expect(result.narrativeLocations, ['Fantasy land']);
      expect(result.country, 'United States');
      expect(result.locationSource, 'https://www.wikidata.org/wiki/Q123');
      service.close();
    },
  );
  test(
    'review gap filling replaces score/count pairs together and never crosses identities',
    () async {
      for (final wrongId in [false, true]) {
        final storage = MemoryStorage();
        final settings = EnrichmentSettingsStore(storage: storage);
        await settings.save(
          const EnrichmentSettings(reviewConnectionId: 'reviews'),
        );
        final integrations = IntegrationStore(storage: storage);
        await integrations.save(
          IntegrationSettings(
            connections: [
              const McpConnection(
                id: 'reviews',
                name: 'Review source',
                url: 'https://metadata.example/mcp',
                metadata: true,
              ),
            ],
          ),
        );
        var calls = 0;
        MetadataService factory(McpConnection c) {
          calls++;
          return ReviewCatalog(
            MediaTitle(
              imdbId: wrongId ? 'tt9999999' : film.imdbId,
              title: film.title,
              year: film.year,
              kind: film.kind,
              ratings: const {
                'Rotten Tomatoes': '97%',
                'Metacritic': '99/100',
                'IMDb': '999/10',
              },
              ratingCounts: const {'Rotten Tomatoes': 240, 'IMDb': 5},
            ),
          );
        }

        final service = MetadataEnrichment(
          storage: storage,
          settings: settings,
          integrations: integrations,
          reviewFactory: factory,
        );
        final result = await service.enrich(film);
        expect(result.ratings['Rotten Tomatoes'], wrongId ? '95%' : '97%');
        expect(result.ratingCounts['Rotten Tomatoes'], wrongId ? isNull : 240);
        expect(
          result.ratingProviders['Rotten Tomatoes'],
          wrongId ? isNull : 'Review source',
        );
        expect(result.ratings['Metacritic'], '82/100');
        expect(result.ratings['IMDb'], isNull);
        await service.enrich(film);
        expect(calls, 1);
        service.close();
      }
    },
  );
  test(
    'chosen identities survive snapshot eviction and reopen without title searches',
    () async {
      final storage = MemoryStorage(), service = IdentityCatalog();
      var matches = SuggestionMetadata(
        storage: storage,
        service: service,
        settings: Settings(),
      );
      await matches.load();
      const pick = FilmSuggestion(
        title: 'Wrong name',
        year: 2009,
        description: 'Pick',
        reason: 'Test',
      );
      await matches.confirm(pick, film);
      for (var i = 0; i < 100; i++) {
        final title = MediaTitle(
          imdbId: 'tt${(2000000 + i)}',
          title: 'Title $i',
          year: '2009',
          kind: 'movie',
        );
        await matches.confirm(
          FilmSuggestion(
            title: title.title,
            year: 2009,
            description: 'Pick',
            reason: 'Test',
          ),
          title,
        );
      }
      matches.dispose();
      matches = SuggestionMetadata(
        storage: storage,
        service: service,
        settings: Settings(),
      );
      await matches.load();
      expect(matches.forFilm(pick)?.imdbId, film.imdbId);
      await matches.enrich(pick);
      expect(service.ids.last, film.imdbId);
      expect(service.searches, 0);
      matches.dispose();
      service.close();
    },
  );
  testWidgets(
    'cast, spoilers and geography stay readable on narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final media = MediaTitle.fromJson({
        ...film.toJson(),
        'cast': [
          {'name': 'Actor One', 'character': 'Explorer'},
        ],
        'topics': ['friendship'],
        'filmingLocations': ['Studio'],
        'narrativeLocations': ['Fantasy land'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TitleInformation(media: media),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Actor One'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('friendship'), findsNothing);
      await tester.ensureVisible(find.text('Show topics'));
      await tester.tap(find.text('Show topics'));
      await tester.pumpAndSettle();
      expect(find.text('friendship'), findsOneWidget);
      expect(find.text('Filmed in'), findsOneWidget);
      expect(find.text('Story setting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
