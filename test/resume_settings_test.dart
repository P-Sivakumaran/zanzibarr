import 'package:zanzibarr/metadata/metadata_screen.dart';
import 'package:zanzibarr/metadata/film_blurb.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/metadata/artwork.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/title_library.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/settings/settings_home.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/chat/ai_connections_screen.dart';
import 'metadata_library_test.dart'
    show
        MemoryStorage,
        FixtureArt,
        LocalWatchlist,
        NoUpdate,
        ReadyProvider,
        LocalHistory,
        app;

const media = MediaTitle(
  imdbId: 'tt1234567',
  title: 'The Quiet Coast',
  kind: 'series',
  year: '2026',
  plot:
      'A lighthouse keeper returns home to a coast full of secrets. An old disappearance connects the people she thought she knew.',
  genre: 'Drama / Mystery',
  runtime: '48 min',
  certification: 'TV-14',
  poster: 'https://m.media-amazon.com/coast.jpg',
  ratingCounts: {'IMDb': 123456, 'Rotten Tomatoes': 240, 'Metacritic': 45},
  ratings: {'IMDb': '8.2/10', 'Rotten Tomatoes': '87%', 'Metacritic': '76/100'},
);
const entry = PlaybackHistoryEntry(
  nzbPath: '/saved/coast.nzb',
  entryKey: 'episode-3',
  title: 'The.Quiet.Coast.S01E03.2160p.WEB-DL.x265-GROUP.mkv',
  positionSeconds: 1800,
  durationSeconds: 2880,
  updatedAtMs: 1,
  imdbId: 'tt1234567',
  season: 1,
  episode: 3,
  sourceId: 'indexer-id',
  nzbUrl: 'https://indexer.example/release',
);

class Catalog extends MetadataService {
  int loads = 0;
  @override
  Future<MetadataPage> search(
    String key,
    String query, {
    String? kind,
    int page = 1,
    int? year,
  }) async => const MetadataPage([media]);
  @override
  Future<MediaTitle?> details(String key, String id) async {
    loads++;
    return media;
  }
}

class Settings extends MetadataSettingsStore {
  Settings([this.key = 'TESTPASS123']);
  String key;
  @override
  Future<String> load() async => key;
}

void main() {
  testWidgets(
    'history title chooser returns metadata without a release-search route',
    (tester) async {
      final catalog = Catalog();
      addTearDown(catalog.close);
      MediaTitle? selected;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.push<MediaTitle>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MetadataScreen(
                        service: catalog,
                        store: Settings(),
                        selectTitleOnly: true,
                        initialQuery: 'The Quiet Coast',
                        initialKind: 'series',
                      ),
                    ),
                  );
                },
                child: const Text('Match release'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Match release'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(media.title).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(media.title).last);
      await tester.pumpAndSettle();
      expect(selected?.imdbId, media.imdbId);
      expect(catalog.loads, 0);
    },
  );
  testWidgets('known resume identity loads metadata automatically', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final history = LocalHistory([entry]);
    final library = TitleLibraryStore(storage: storage);
    final catalog = Catalog();
    addTearDown(catalog.close);
    await tester.pumpWidget(
      app(
        HomeScreen(
          historyStore: history,
          titleLibraryStore: library,
          metadataService: catalog,
          metadataSettings: Settings(),
          watchlistStore: LocalWatchlist(),
          updateService: NoUpdate(),
          providerStore: ReadyProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your next screening'), findsNothing);
    expect(catalog.loads, 1);
    expect(find.text(filmBlurb(media)), findsOneWidget);
    expect(find.text(media.plot), findsNothing);
    expect(find.text('Metacritic: 76/100'), findsOneWidget);
    expect((await library.load()).single.poster, media.poster);
    final saved = (await history.load()).single;
    expect(saved.positionSeconds, entry.positionSeconds);
    expect(saved.entryKey, entry.entryKey);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'returning from Settings retries automatic resume enrichment after key setup',
    (tester) async {
      final settings = Settings('');
      final catalog = Catalog();
      addTearDown(catalog.close);
      final storage = MemoryStorage();
      await tester.pumpWidget(
        app(
          HomeScreen(
            historyStore: LocalHistory([entry]),
            titleLibraryStore: TitleLibraryStore(storage: storage),
            metadataService: catalog,
            metadataSettings: settings,
            watchlistStore: LocalWatchlist(),
            updateService: NoUpdate(),
            providerStore: ReadyProvider(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(catalog.loads, 0);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      settings.key = 'TESTPASS123';
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(catalog.loads, 1);
      expect(find.text(filmBlurb(media)), findsOneWidget);
      expect(find.text(media.plot), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'AI connection back protects a draft and the save action remains visible',
    (tester) async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      await store.save(const AiConnections(provider: FilmAiProvider.claude));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiConnectionsScreen(store: store),
                  ),
                ),
                child: const Text('Open AI'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open AI'));
      await tester.pumpAndSettle();
      final keyField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Claude API key',
      );
      await tester.enterText(keyField, 'TESTPASS123');
      expect(
        find.byKey(const Key('save-ai-connections')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Claude model ID'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard connection changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(keyField).controller!.text,
        'TESTPASS123',
      );
      await tester.tap(find.byKey(const Key('save-ai-connections')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open AI'), findsOneWidget);
      expect((await store.load()).claudeKey, 'TESTPASS123');
    },
  );
  for (final width in [1280.0, 360.0]) {
    testWidgets('resume and settings layout at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final shots = Platform.environment['GENERATE_RESUME_SCREENSHOTS'] == '1';
      if (shots) {
        await (FontLoader(
          'Noto Sans',
        )..addFont(rootBundle.load('assets/fonts/subtitle.ttf'))).load();
        await (FontLoader(
          'League Mono',
        )..addFont(rootBundle.load('assets/fonts/LeagueMono-Thin.ttf'))).load();
        var dir = File(Platform.resolvedExecutable).parent;
        for (var i = 0; i < 8; i++) {
          final file = File(
            '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
          );
          if (file.existsSync()) {
            await (FontLoader('MaterialIcons')..addFont(
                  Future.value(ByteData.sublistView(file.readAsBytesSync())),
                ))
                .load();
            break;
          }
          dir = dir.parent;
        }
      }
      final bytes = (await tester.runAsync(
        () => File('test/fixtures/figma/quiet-coast.png').readAsBytes(),
      ))!;
      final art = FixtureArt(bytes);
      final storage = MemoryStorage();
      final library = TitleLibraryStore(storage: storage);
      await library.save(media);
      final history = LocalHistory([entry]);
      final service = Catalog();
      addTearDown(art.close);
      addTearDown(service.close);
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const Key('resume-preview'),
            child: HomeScreen(
              historyStore: history,
              titleLibraryStore: library,
              metadataService: service,
              metadataSettings: Settings(),
              watchlistStore: LocalWatchlist(),
              updateService: NoUpdate(),
              artworkLoader: art,
            ),
          ),
          scale: width < 400 ? 1.4 : 1,
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(
          ResizeImage(MemoryImage(bytes), width: 500),
          tester.element(find.byType(TitleArtwork).first),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(filmBlurb(media)), findsOneWidget);
      expect(find.text(media.plot), findsNothing);
      expect(find.text('Rotten Tomatoes: 87% positive'), findsOneWidget);
      expect(find.text('Metacritic: 76/100'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (shots) {
        await expectLater(
          find.byKey(const Key('resume-preview')),
          matchesGoldenFile(
            '../docs/screenshots/resume-${width.toInt()}-flutter.png',
          ),
        );
      }
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const Key('settings-preview'),
            child: SettingsHomeScreen(providerStore: ReadyProvider()),
          ),
          scale: width < 400 ? 2 : 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (shots) {
        await expectLater(
          find.byKey(const Key('settings-preview')),
          matchesGoldenFile(
            '../docs/screenshots/settings-${width.toInt()}-flutter.png',
          ),
        );
      }
      if (width > 1000) {
        final aiStore = AiConnectionStore(storage: storage);
        await aiStore.save(
          const AiConnections(provider: FilmAiProvider.claude),
        );
        await tester.pumpWidget(
          app(
            RepaintBoundary(
              key: const Key('ai-preview'),
              child: AiConnectionsScreen(store: aiStore),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (shots) {
          await expectLater(
            find.byKey(const Key('ai-preview')),
            matchesGoldenFile('../docs/screenshots/ai-settings-flutter.png'),
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
