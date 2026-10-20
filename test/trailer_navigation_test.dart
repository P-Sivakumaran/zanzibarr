import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zanzibarr/metadata/trailer_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:zanzibarr/metadata/title_trailer.dart';
import 'package:zanzibarr/metadata/trailer_panel.dart';
import 'package:zanzibarr/metadata/metadata_enrichment.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/title_details_screen.dart';
import 'package:zanzibarr/chat/suggestion_details_screen.dart';
import 'package:zanzibarr/chat/suggestion_metadata.dart';
import 'package:zanzibarr/chat/film_chat_screen.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'metadata_library_test.dart' show MemoryStorage, app;
import 'automatic_metadata_test.dart' show Settings;
import 'film_chat_test.dart' show FakeCodex, film, settleChat;

const media = MediaTitle(
  imdbId: 'tt2543164',
  title: 'Arrival',
  year: '2016',
  kind: 'movie',
  genre: 'Drama, Sci-Fi',
);
const trailer = TitleTrailer(key: 'dQw4w9WgXcQ', name: 'Official trailer');

class Catalog extends MetadataService {
  Completer<MediaTitle?>? hold;
  @override
  Future<MediaTitle?> details(String key, String id) async =>
      hold == null ? media : hold!.future;
  @override
  Future<MetadataPage> search(
    String key,
    String query, {
    String? kind,
    int page = 1,
    int? year,
  }) async => const MetadataPage([media]);
}

class RecordingBrowser extends Fake implements InAppWebViewController {
  String? method;
  Map<String, dynamic>? parameters;
  URLRequest? request;
  dynamic result = <String, dynamic>{'frameId': 'frame'};
  @override
  Future<dynamic> callDevToolsProtocolMethod({
    required String methodName,
    Map<String, dynamic>? parameters,
  }) async {
    method = methodName;
    this.parameters = parameters;
    return result;
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    request = urlRequest;
  }
}

void main() {
  test(
    'Windows trailer sets browser navigation referrer instead of only HTTP headers',
    () async {
      final browser = RecordingBrowser();
      await navigateTrailer(browser, trailer, platform: TargetPlatform.windows);
      expect(browser.method, 'Page.navigate');
      expect(browser.parameters, {
        'url': trailer.embedUri.toString(),
        'referrer': trailerAppReferrer,
        'referrerPolicy': 'strictOriginWhenCrossOrigin',
      });
      expect(browser.request, isNull);
    },
  );
  test('native navigation failures propagate to the retry surface', () async {
    final browser = RecordingBrowser()..result = {'errorText': 'TESTPASS123'};
    await expectLater(
      navigateTrailer(browser, trailer, platform: TargetPlatform.windows),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'sanitized',
          isNot(contains('TESTPASS123')),
        ),
      ),
    );
  });
  test('other native platforms preserve app identity headers', () async {
    final browser = RecordingBrowser();
    await navigateTrailer(browser, trailer, platform: TargetPlatform.android);
    expect(browser.method, isNull);
    expect(browser.request!.headers, {'Referer': trailerAppReferrer});
    expect(browser.request!.url, WebUri.uri(trailer.embedUri));
  });

  test(
    'trailers reject arbitrary URLs, clips and unofficial uploads and rank English trailers',
    () {
      expect(TitleTrailer.fromJson({'key': 'https://evil.test'}), isNull);
      final selected = selectTitleTrailer({
        'results': [
          {
            'key': 'AAAAAAAAAAA',
            'site': 'YouTube',
            'official': true,
            'type': 'Teaser',
            'iso_639_1': 'en',
          },
          {
            'key': 'BBBBBBBBBBB',
            'site': 'YouTube',
            'official': false,
            'type': 'Trailer',
          },
          {
            'key': 'CCCCCCCCCCC',
            'site': 'YouTube',
            'official': true,
            'type': 'Clip',
          },
          {
            'key': 'DDDDDDDDDDD',
            'site': 'Vimeo',
            'official': true,
            'type': 'Trailer',
          },
          {
            'key': 'EEEEEEEEEEE',
            'site': 'YouTube',
            'official': true,
            'type': 'Trailer',
            'iso_639_1': 'fr',
          },
          {
            'key': trailer.key,
            'name': trailer.name,
            'site': 'YouTube',
            'official': true,
            'type': 'Trailer',
            'iso_639_1': 'en',
          },
        ],
      });
      expect(selected?.key, trailer.key);
      expect(selected?.embedUri.host, 'www.youtube-nocookie.com');
      expect(selected?.embedUri.queryParameters['autoplay'], '0');
      expect(TitleTrailer.fromJson(selected!.toJson())?.key, trailer.key);
    },
  );
  test(
    'TMDB trailer shares verified identity request and persistent cache',
    () async {
      final storage = MemoryStorage();
      final settings = EnrichmentSettingsStore(storage: storage);
      await settings.save(const EnrichmentSettings(tmdbToken: 'TESTPASS123'));
      var calls = 0;
      final enrich = MetadataEnrichment(
        storage: storage,
        settings: settings,
        client: MockClient((req) async {
          calls++;
          if (req.url.path.contains('/find/')) {
            return http.Response(
              jsonEncode({
                'movie_results': [
                  {'id': 329865},
                ],
              }),
              200,
            );
          }
          expect(
            req.url.queryParameters['append_to_response'],
            contains('videos'),
          );
          return http.Response(
            jsonEncode({
              'id': 329865,
              'external_ids': {'imdb_id': media.imdbId},
              'videos': {
                'results': [
                  {
                    'key': trailer.key,
                    'name': trailer.name,
                    'site': 'YouTube',
                    'official': true,
                    'type': 'Trailer',
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(enrich.close);
      final result = await enrich.enrich(media);
      expect(result.trailer?.key, trailer.key);
      expect(MediaTitle.fromJson(result.toJson()).trailer?.key, trailer.key);
      expect((await enrich.enrich(media)).trailer?.key, trailer.key);
      expect(calls, 2);
      expect(
        storage.values['metadata.enrichment.cache.v1'],
        isNot(contains('TESTPASS123')),
      );
    },
  );
  testWidgets(
    'trailer only creates player on click and supports close/error/retry at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var builds = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: TrailerPanel(
                trailer: trailer,
                configured: true,
                playerBuilder: (_, _, onError) {
                  builds++;
                  return TextButton(
                    onPressed: onError,
                    child: const Text('Player fixture'),
                  );
                },
              ),
            ),
          ),
          scale: 1.5,
        ),
      );
      expect(builds, 0);
      await tester.tap(find.text('Load trailer'));
      await tester.pump();
      expect(find.text('Player fixture'), findsOneWidget);
      await tester.tap(find.text('Player fixture'));
      await tester.pump();
      expect(
        find.textContaining('Embedded playback is unavailable'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry embedded trailer'));
      await tester.pump();
      expect(find.text('Player fixture'), findsOneWidget);
      await tester.tap(find.text('Close trailer'));
      await tester.pump();
      expect(find.text('Player fixture'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('details waits for an identification already in progress', (
    tester,
  ) async {
    final catalog = Catalog()..hold = Completer<MediaTitle?>();
    final matches = SuggestionMetadata(
      service: catalog,
      settings: Settings(),
      storage: MemoryStorage(),
    );
    await matches.load();
    final pending = matches.enrich(film);
    await tester.pumpWidget(
      app(
        SuggestionDetailsScreen(
          film: film,
          metadata: matches,
          onRematch: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Loading title details...'), findsOneWidget);
    catalog.hold!.complete(media);
    await pending;
    await tester.pumpAndSettle();
    expect(find.byType(TitleDetailsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    matches.dispose();
    catalog.close();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'playlist card heading opens details; Find releases remains independent',
    (tester) async {
      final storage = MemoryStorage();
      final playlists = FilmPlaylistStore(storage: storage);
      await playlists.save([
        FilmPlaylist(id: 'p', name: 'Weekend', films: const [film]),
      ]);
      final catalog = Catalog();
      final matches = SuggestionMetadata(
        service: catalog,
        settings: Settings(),
        storage: storage,
      );
      await matches.load();
      await matches.confirm(film, media);
      final runtime = IntegrationRuntime(
        store: IntegrationStore(storage: storage),
      );
      await runtime.load();
      final fake = FakeCodex();
      var searched = 0;
      await tester.pumpWidget(
        app(
          FilmChatScreen(
            initialTab: 1,
            account: fake.account,
            runtime: runtime,
            aiStore: AiConnectionStore(storage: storage),
            playlistStore: playlists,
            suggestionMetadata: matches,
            onFindReleases: (_) async {
              searched++;
            },
          ),
        ),
      );
      await settleChat(tester);
      await tester.tap(find.text('Weekend'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Arrival (2016)'));
      await tester.tap(find.text('Arrival (2016)'));
      await tester.pumpAndSettle();
      expect(find.byType(TitleDetailsScreen), findsOneWidget);
      expect(searched, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find releases'));
      await tester.tap(find.text('Find releases'));
      await tester.pumpAndSettle();
      expect(searched, 1);
      expect(find.byType(SuggestionDetailsScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settleChat(tester);
      fake.account.dispose();
      matches.dispose();
      catalog.close();
      await runtime.shutdown();
      expect(tester.takeException(), isNull);
    },
  );
}
