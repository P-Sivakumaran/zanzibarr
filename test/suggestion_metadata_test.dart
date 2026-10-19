import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/chat/film_chat_screen.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:zanzibarr/chat/suggestion_metadata.dart';
import 'package:zanzibarr/metadata/artwork.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/metadata_visuals.dart';
import 'film_chat_test.dart' show FakeCodex, settleChat;
import 'metadata_library_test.dart' show MemoryStorage, FixtureArt, app;

const pick = FilmSuggestion(
  title: 'The Quiet Coast',
  year: 2026,
  kind: DiscoveryKind.tv,
  description: 'A coastal mystery unfolds.',
  reason: 'For a thoughtful evening.',
);
const title = MediaTitle(
  imdbId: 'tt1234567',
  title: 'The Quiet Coast',
  year: '2026',
  kind: 'series',
  poster: 'https://m.media-amazon.com/coast.jpg',
  runtime: '48 min',
  genre: 'Drama / Mystery',
  ratings: {'IMDb': '8.2/10', 'Rotten Tomatoes': '87%'},
);

class Settings extends MetadataSettingsStore {
  @override
  Future<String> load() async => 'TESTPASS123';
}

class Catalog extends MetadataService {
  @override
  Future<MetadataPage> search(
    String key,
    String query, {
    String? kind,
    int page = 1,
    int? year,
  }) async => const MetadataPage([title]);
  @override
  Future<MediaTitle?> details(String key, String id) async => title;
}

void main() {
  test(
    'artwork is confirmed, persisted, shared and preserved on write failure',
    () async {
      final storage = MemoryStorage();
      final service = Catalog();
      final matches = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      await matches.load();
      expect(matches.forFilm(pick), isNull);
      expect(await matches.candidates(pick), [title]);
      expect(matches.forFilm(pick), isNull);
      await matches.confirm(pick, title);
      expect(matches.forFilm(pick)?.imdbId, title.imdbId);
      final restored = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      await restored.load();
      expect(restored.forFilm(pick)?.poster, title.poster);
      storage.failWrite = true;
      await expectLater(restored.confirm(pick, title), throwsStateError);
      expect(restored.forFilm(pick)?.poster, title.poster);
      expect(pick.selection.imdbId, isNull);
      matches.dispose();
      restored.dispose();
      service.close();
    },
  );
  test(
    'corrupt cache blocks replacement and wrong-kind confirmation',
    () async {
      final storage = MemoryStorage()
        ..values['metadata.suggestion-matches.v1'] = '{';
      final service = Catalog();
      final matches = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      await matches.load();
      await expectLater(
        matches.confirm(pick, title),
        throwsA(isA<MetadataException>()),
      );
      expect(storage.values.values.single, '{');
      storage.values.clear();
      await matches.load();
      await expectLater(
        matches.confirm(
          pick,
          const MediaTitle(
            imdbId: 'tt1111111',
            title: 'Wrong type',
            kind: 'movie',
            year: '2026',
          ),
        ),
        throwsA(isA<MetadataException>()),
      );
      matches.dispose();
      service.close();
    },
  );
  testWidgets('rating meters expose scores and respect reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: RatingMeters(media: title)),
        ),
      ),
    );
    await tester.pump();
    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(bars.map((b) => b.value), [.82, .87]);
    expect(find.text('IMDb: 8.2/10'), findsOneWidget);
  });
  for (final size in [const Size(1440, 1100), const Size(360, 900)]) {
    testWidgets('playlist artwork and metadata at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final service = Catalog();
      final matches = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      await matches.load();
      final playlists = FilmPlaylistStore(storage: storage);
      await playlists.save([
        FilmPlaylist(
          id: 'coast',
          name: 'An evening by the sea',
          films: const [pick],
        ),
      ]);
      final fake = FakeCodex()..suggestions = const [pick];
      final runtime = IntegrationRuntime(
        store: IntegrationStore(storage: storage),
      );
      await runtime.load();
      await runtime.save(
        runtime.settings!.copyWith(codexExecutable: 'codex.exe'),
      );
      addTearDown(runtime.shutdown);
      final bytes = (await tester.runAsync(
        () => File('test/fixtures/figma/quiet-coast.png').readAsBytes(),
      ))!;
      final art = FixtureArt(bytes);
      addTearDown(() {
        matches.dispose();
        service.close();
        art.close();
        fake.account.dispose();
      });
      final shots = Platform.environment['GENERATE_LAYOUT_SCREENSHOTS'] == '1';
      if (shots) {
        await (FontLoader(
          'Noto Sans',
        )..addFont(rootBundle.load('assets/fonts/subtitle.ttf'))).load();
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
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const Key('playlist-preview'),
            child: FilmChatScreen(
              initialTab: 1,
              runtime: runtime,
              aiStore: AiConnectionStore(storage: storage),
              account: fake.account,
              playlistStore: playlists,
              suggestionMetadata: matches,
              artworkLoader: art,
              onFindReleases: (_) async {},
            ),
          ),
          scale: size.width < 400 ? 1.4 : 1,
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
      expect(
        fake.sent,
        isEmpty,
        reason: 'Viewing playlists must not start the AI connection',
      );
      expect(find.byType(TitleArtwork), findsOneWidget);
      await tester.tap(find.text('An evening by the sea'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingMeters), findsOneWidget);
      expect(find.byType(TitleArtwork), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      if (shots) {
        await expectLater(
          find.byKey(const Key('playlist-preview')),
          matchesGoldenFile(
            '../docs/screenshots/playlists-${size.width.toInt()}-flutter.png',
          ),
        );
      }
      if (size.width > 1000) {
        await fake.account.connect('codex.exe');
        await tester.tap(find.text('Chat'));
        await settleChat(tester);
        await tester.pumpAndSettle();
        expect(
          DefaultTabController.of(tester.element(find.byType(TabBar))).index,
          0,
        );
        await tester.enterText(
          find.byKey(const Key('chat-prompt')),
          'A thoughtful mystery',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        await tester.pumpAndSettle();
        expect(
          fake.threads,
          1,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join('|'),
        );
        expect(find.byType(RatingMeters), findsOneWidget);
        expect(find.byType(TitleArtwork), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (shots) {
          await expectLater(
            find.byKey(const Key('playlist-preview')),
            matchesGoldenFile(
              '../docs/screenshots/suggestions-artwork-flutter.png',
            ),
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
