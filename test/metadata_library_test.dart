import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_kit/media_kit.dart';
import 'package:zanzibarr/l10n/app_localizations.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/update/update_service.dart';
import 'package:zanzibarr/metadata/artwork.dart';
import 'package:zanzibarr/metadata/library_screen.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/title_details_screen.dart';
import 'package:zanzibarr/metadata/title_library.dart';
import 'package:zanzibarr/player/media_preferences.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/player/track_language.dart';
import 'package:zanzibarr/player/watchlist.dart';
import 'package:zanzibarr/search/release_search_selection.dart';
import 'package:zanzibarr/settings/language_settings.dart';
import 'package:zanzibarr/settings/provider_settings.dart';

class MemoryStorage implements PlayerPreferenceStorage {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('storage unavailable');
    values[key] = value;
  }
}

class LocalWatchlist extends WatchlistStore {
  @override
  Future<List<WatchlistEntry>> load() async => [];
  @override
  Future<bool> isTracked(String id) async => false;
}

class LocalHistory extends PlaybackHistoryStore {
  LocalHistory([this.entries = const []]);
  final List<PlaybackHistoryEntry> entries;
  @override
  Future<List<PlaybackHistoryEntry>> load() async => entries;
}

class ReadyProvider extends ProviderSettingsStore {
  @override
  Future<ProviderSettings> load() async => const ProviderSettings(
    host: 'news.example.com',
    username: 'user',
    password: 'TESTPASS123',
  );
}

class NoUpdate extends UpdateService {
  @override
  Future<ReleaseInfo?> checkForUpdate({bool ignoreSkipped = false}) async =>
      null;
}

const show = MediaTitle(
  imdbId: 'tt1234567',
  title: 'The Quiet Coast',
  kind: 'series',
  year: '2026',
  genre: 'Drama',
  plot: 'Some secrets only surface at low tide.',
  totalSeasons: 2,
  ratings: {'IMDb': '8.2/10', 'Rotten Tomatoes': '87%'},
  originalLanguage: 'English',
);

class Catalog extends MetadataService {
  int? selectedSeason;
  @override
  Future<MediaTitle?> details(String apiKey, String id) async => show;
  @override
  Future<List<MediaEpisode>> season(
    String apiKey,
    String id,
    int season,
  ) async {
    expect(id, show.imdbId);
    selectedSeason = season;
    return [
      const MediaEpisode(number: 1, title: 'The lighthouse'),
      MediaEpisode(number: 2, title: 'Tomorrow', aired: DateTime(2200)),
    ];
  }
}

class FixtureArt extends ArtworkLoader {
  FixtureArt(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> load(String url) async => bytes;
}

Widget app(Widget home, {double scale = 1, bool rtl = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  theme: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFFFF654F),
    scaffoldBackgroundColor: const Color(0xFF101313),
    fontFamily: 'Noto Sans',
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: child!,
    ),
  ),
  home: home,
);

void main() {
  test(
    'old plugin objects parse; rich metadata round trips without guessed fields',
    () {
      final old = MediaTitle.fromJson({
        'imdbID': 'tt1234567',
        'Title': 'A',
        'Year': '2026',
        'Type': 'series',
      });
      expect(old.poster, '');
      expect(old.totalSeasons, isNull);
      final restored = MediaTitle.fromJson(show.toJson());
      expect(restored.ratings, show.ratings);
      expect(restored.totalSeasons, 2);
      expect(restored.originalLanguage, 'English');
    },
  );
  test(
    'season catalog accepts specials, deduplicates and rejects wrong season',
    () {
      final data = <String, dynamic>{
        'Season': '0',
        'Episodes': [
          {'Episode': '2', 'Title': 'Special two', 'Released': 'N/A'},
          {'Episode': '1', 'Title': 'Special one', 'Released': '2026-01-01'},
          {'Episode': '1', 'Title': 'Duplicate'},
          {'Episode': 'bad', 'Title': 'Bad'},
        ],
      };
      final episodes = parseSeason(data, 0);
      expect(episodes.map((e) => e.number), [1, 2]);
      expect(episodes.last.aired, isNull);
      expect(() => parseSeason(data, 1), throwsA(isA<MetadataException>()));
    },
  );
  test('season requests retain show identity and coalesce requests', () async {
    var requests = 0;
    final service = MetadataService(
      client: MockClient((r) async {
        requests++;
        expect(r.url.queryParameters['i'], show.imdbId);
        expect(r.url.queryParameters['Season'], '2');
        expect(r.followRedirects, false);
        return http.Response(
          jsonEncode({
            'Season': '2',
            'Episodes': [
              {'Episode': '1', 'Title': 'One'},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final results = await Future.wait([
      service.season('TESTPASS123', show.imdbId, 2),
      service.season('TESTPASS123', show.imdbId, 2),
    ]);
    expect(requests, 1);
    expect(results.first.single.number, 1);
  });
  test(
    'library serializes concurrent saves, retains metadata and surfaces failures',
    () async {
      final storage = MemoryStorage();
      final store = TitleLibraryStore(storage: storage);
      const movie = MediaTitle(
        imdbId: 'tt2345678',
        title: 'Film',
        year: '2025',
        kind: 'movie',
      );
      await Future.wait([store.save(show), store.save(movie)]);
      expect((await store.load()).length, 2);
      expect((await store.load()).last.ratings, show.ratings);
      storage.failWrite = true;
      await expectLater(store.remove(show.imdbId), throwsStateError);
      expect((await store.load()).length, 2);
    },
  );
  test('artwork rejects local hosts, credentials and redirects', () async {
    for (final url in [
      'http://m.media-amazon.com/a.jpg',
      'https://127.0.0.1/a',
      'https://m.media-amazon.com.evil.test/a',
      'https://user:pass@m.media-amazon.com/a',
      'https://image.tmdb.org:8443/a',
      'https://image.tmdb.org/a?token=TESTPASS123',
    ]) {
      expect(artworkUri(url), isNull);
    }
    var requests = 0;
    final loader = ArtworkLoader(
      client: MockClient((r) async {
        requests++;
        expect(r.followRedirects, false);
        return http.Response(
          '',
          302,
          headers: {'location': 'http://127.0.0.1/'},
        );
      }),
    );
    addTearDown(loader.close);
    expect(await loader.load('https://127.0.0.1/a'), isNull);
    expect(requests, 0);
    expect(await loader.load('https://image.tmdb.org/a'), isNull);
    expect(requests, 1);
  });
  test(
    'language normalization preserves unknowns and region, matches only actual tracks',
    () async {
      expect(normalizeTrackLanguage('ENG_us'), 'en-us');
      expect(trackLanguageLabel('eng-US'), 'English (US)');
      expect(trackLanguageLabel('und'), 'Unknown language');
      expect(trackLanguageLabel('xyz'), 'xyz');
      const tracks = [
        AudioTrack('1', null, 'fra'),
        AudioTrack('2', null, 'eng'),
      ];
      expect(preferredAudio(tracks, 'en')?.id, '2');
      expect(preferredAudio(tracks, 'ja'), isNull);
      expect(
        preferredSubtitle([const SubtitleTrack('1', 'SDH', 'eng')], 'no')?.id,
        'no',
      );
      final storage = MemoryStorage();
      final store = TrackLanguageStore(storage: storage);
      await store.save(
        const TrackLanguagePreferences(audio: 'fr', subtitle: 'no'),
      );
      final saved = await store.load();
      expect(saved.audio, 'fr');
      expect(saved.subtitle, 'no');
    },
  );
  test('artwork concurrency and preference failures stay bounded', () async {
    var active = 0, maximum = 0;
    final release = Completer<void>();
    final loader = ArtworkLoader(
      client: MockClient((r) async {
        active++;
        if (active > maximum) maximum = active;
        await release.future;
        active--;
        return http.Response('', 400);
      }),
    );
    final requests = [
      for (var i = 0; i < 12; i++) loader.load('https://image.tmdb.org/$i.jpg'),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(maximum, 4);
    release.complete();
    await Future.wait(requests);
    expect(maximum, 4);
    loader.close();
    final storage = MemoryStorage();
    final policy = ArtworkPreferences(storage: storage);
    await policy.load();
    expect(policy.enabled, false);
    await policy.setEnabled(true);
    expect(policy.enabled, true);
    storage.failWrite = true;
    await policy.setEnabled(false);
    expect(policy.enabled, true);
    expect(policy.error, isNotNull);
    policy.dispose();
  });
  test('oversized artwork is refused before decoding', () async {
    final loader = ArtworkLoader(
      client: MockClient(
        (r) async => http.Response(
          'x' * (5 * 1024 * 1024 + 1),
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
    );
    expect(await loader.load('https://image.tmdb.org/large.png'), isNull);
    loader.close();
  });
  test('a full library never silently evicts saved titles', () async {
    final storage = MemoryStorage();
    storage.values['metadata.library.v1'] = jsonEncode([
      for (var i = 0; i < 300; i++)
        {...show.toJson(), 'imdbID': 'tt${1000000 + i}'},
    ]);
    final store = TitleLibraryStore(storage: storage);
    await expectLater(store.save(show), throwsA(isA<LibraryFull>()));
    expect((await store.load()).length, 300);
    expect((await store.load()).first.imdbId, 'tt1000000');
  });
  testWidgets(
    'Home fits narrow large text and Resume preserves saved release identity',
    (tester) async {
      final storage = MemoryStorage();
      const entry = PlaybackHistoryEntry(
        nzbPath: '/saved/show.nzb',
        entryKey: 'episode-key',
        title: 'Saved release',
        positionSeconds: 500,
        durationSeconds: 1800,
        updatedAtMs: 1,
        imdbId: 'tt1234567',
        season: 2,
        episode: 1,
      );
      String? openedPath, openedKey;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          HomeScreen(
            historyStore: LocalHistory([entry]),
            providerStore: ReadyProvider(),
            watchlistStore: LocalWatchlist(),
            titleLibraryStore: TitleLibraryStore(storage: storage),
            updateService: NoUpdate(),
            fileExistsFn: (_) async => true,
            playerBuilder: (path, key) {
              openedPath = path;
              openedKey = key;
              return const Scaffold(body: Text('Playing saved release'));
            },
          ),
          scale: 2,
          rtl: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Resume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(openedPath, entry.nzbPath);
      expect(openedKey, entry.entryKey);
    },
  );
  testWidgets(
    'episode action passes parent identity and exact season/episode',
    (tester) async {
      final storage = MemoryStorage();
      final service = Catalog();
      addTearDown(service.close);
      ReleaseSearchSelection? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<ReleaseSearchSelection>(
                        MaterialPageRoute(
                          builder: (_) => TitleDetailsScreen(
                            title: show,
                            service: service,
                            apiKey: 'TESTPASS123',
                            libraryStore: TitleLibraryStore(storage: storage),
                            watchlistStore: LocalWatchlist(),
                            historyStore: PlaybackHistoryStore(
                              storage: storage,
                            ),
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Season 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Season 2'));
      await tester.pumpAndSettle();
      expect(service.selectedSeason, 2);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Find episode releases').last,
            )
            .onPressed,
        isNull,
      );
      final findEpisode = find
          .widgetWithText(OutlinedButton, 'Find episode releases')
          .first;
      await tester.ensureVisible(findEpisode);
      await tester.pumpAndSettle();
      await tester.tap(findEpisode);
      await tester.pumpAndSettle();
      expect(result?.imdbId, show.imdbId);
      expect(result?.season, 2);
      expect(result?.episode, 1);
      expect(result?.kind, 'tv');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed library writes retain saved state and offer retry', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final service = Catalog();
    addTearDown(service.close);
    await tester.pumpWidget(
      app(
        TitleDetailsScreen(
          title: show,
          service: service,
          apiKey: 'TESTPASS123',
          libraryStore: TitleLibraryStore(storage: storage),
          watchlistStore: LocalWatchlist(),
          historyStore: LocalHistory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    storage.failWrite = true;
    await tester.ensureVisible(find.text('Save to library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Save to library'), findsOneWidget);
    expect(find.textContaining('Could not save changes'), findsOneWidget);
    storage.failWrite = false;
    await tester.tap(find.text('Save to library'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from library'), findsOneWidget);
    expect(
      (await TitleLibraryStore(storage: storage).load()).single.imdbId,
      show.imdbId,
    );
  });
  testWidgets('title, library and languages fit 360px at 200% text in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = MemoryStorage();
    final service = Catalog();
    addTearDown(service.close);
    await tester.pumpWidget(
      app(
        TitleDetailsScreen(
          title: show,
          service: service,
          apiKey: 'TESTPASS123',
          libraryStore: TitleLibraryStore(storage: storage),
          watchlistStore: LocalWatchlist(),
          historyStore: LocalHistory(),
        ),
        scale: 2,
        rtl: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Season 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await TitleLibraryStore(storage: storage).save(show);
    await tester.pumpWidget(
      app(
        LibraryScreen(
          store: TitleLibraryStore(storage: storage),
          watchlistStore: LocalWatchlist(),
          onOpen: (_) async {},
        ),
        scale: 2,
        rtl: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MediaLanguageSettings(
              store: TrackLanguageStore(storage: storage),
            ),
          ),
        ),
        scale: 2,
        rtl: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'library filters saved titles and restores them after changing filter',
    (tester) async {
      final storage = MemoryStorage();
      final store = TitleLibraryStore(storage: storage);
      await store.save(show);
      await store.save(
        const MediaTitle(
          imdbId: 'tt2345678',
          title: 'Film example',
          year: '2025',
          kind: 'movie',
        ),
      );
      await tester.pumpWidget(
        app(
          LibraryScreen(
            store: store,
            watchlistStore: LocalWatchlist(),
            onOpen: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Films'));
      await tester.pumpAndSettle();
      expect(find.text(show.title), findsNothing);
      expect(find.text('Film example'), findsOneWidget);
      await tester.tap(find.text('All titles'));
      await tester.pumpAndSettle();
      expect(find.text(show.title), findsOneWidget);
    },
  );
  testWidgets(
    'render Figma artwork in real title and library widgets',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Noto Sans')
        ..addFont(rootBundle.load('assets/fonts/subtitle.ttf'));
      await font.load();
      final storage = MemoryStorage();
      final service = Catalog();
      FlutterSecureStorage.setMockInitialValues({
        'metadata.artwork.enabled': 'true',
      });
      final loadedBytes = await tester.runAsync(
        () => File('test/fixtures/figma/quiet-coast.png').readAsBytes(),
      );
      final bytes = loadedBytes!;
      final art = FixtureArt(bytes);
      var directory = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8; i++) {
        final candidate = File(
          '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (candidate.existsSync()) {
          final loader = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(ByteData.sublistView(candidate.readAsBytesSync())),
            );
          await loader.load();
          break;
        }
        directory = directory.parent;
      }
      addTearDown(service.close);
      addTearDown(art.close);
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: TitleDetailsScreen(
              title: show,
              service: service,
              apiKey: 'TESTPASS123',
              artworkLoader: art,
              libraryStore: TitleLibraryStore(storage: storage),
              watchlistStore: LocalWatchlist(),
              historyStore: LocalHistory(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await precacheImage(
          ResizeImage(MemoryImage(bytes), width: 500),
          tester.element(find.byType(TitleArtwork).first),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile('../docs/screenshots/metadata-title-flutter.png'),
      );
      await TitleLibraryStore(storage: storage).save(show);
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: LibraryScreen(
              store: TitleLibraryStore(storage: storage),
              watchlistStore: LocalWatchlist(),
              artworkLoader: art,
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await precacheImage(
          ResizeImage(MemoryImage(bytes), width: 500),
          tester.element(find.byType(TitleArtwork).first),
        );
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile('../docs/screenshots/metadata-library-flutter.png'),
      );
      final wordmark = FontLoader('League Mono')
        ..addFont(rootBundle.load('assets/fonts/LeagueMono-Thin.ttf'));
      await wordmark.load();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/zanzibarr-icon-256.png'),
          tester.element(find.byType(LibraryScreen)),
        ),
      );
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const ValueKey('homePreview'),
            child: HomeScreen(
              historyStore: LocalHistory(const [
                PlaybackHistoryEntry(
                  nzbPath: '/sample/show.nzb',
                  title: 'The Quiet Coast',
                  positionSeconds: 1800,
                  durationSeconds: 2880,
                  updatedAtMs: 1,
                  imdbId: 'tt1234567',
                  season: 1,
                  episode: 3,
                ),
              ]),
              watchlistStore: LocalWatchlist(),
              titleLibraryStore: TitleLibraryStore(storage: storage),
              artworkLoader: art,
              updateService: NoUpdate(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('homePreview')),
        matchesGoldenFile('../docs/screenshots/metadata-home-flutter.png'),
      );
    },
    skip: Platform.environment['GENERATE_SCREENSHOTS'] != '1',
  );
}
