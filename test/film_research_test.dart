import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:zanzibarr/chat/film_chat_screen.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/chat/ai_connections_screen.dart';
import 'package:zanzibarr/chat/ai_http.dart';
import 'package:zanzibarr/chat/api_film_chat.dart';
import 'package:zanzibarr/chat/film_research.dart';
import 'package:zanzibarr/chat/research_panel.dart';
import 'package:zanzibarr/chat/research_suggestions.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';

import 'ai_providers_test.dart' show claudeReply, geminiReply, reveal, field;
import 'integrations_test.dart' show MemoryStorage;
import 'film_chat_test.dart' show settleChat;

Map<String, dynamic> claudeResearch({
  String url = 'https://www.criterion.com/films',
  String text = 'An edition was announced.',
}) => {
  'stop_reason': 'end_turn',
  'content': [
    {
      'type': 'text',
      'text': text,
      'citations': [
        {
          'type': 'web_search_result_location',
          'title': 'Criterion',
          'url': url,
        },
      ],
    },
  ],
};
Map<String, dynamic> geminiResearch({bool suggestions = true}) => {
  'candidates': [
    {
      'finishReason': 'STOP',
      'content': {
        'parts': [
          {'text': 'An edition was announced.'},
        ],
      },
      'groundingMetadata': {
        'groundingChunks': [
          {
            'web': {
              'title': 'Criterion',
              'uri': 'https://www.criterion.com/films',
            },
          },
        ],
        'groundingSupports': [
          {
            'segment': {'text': 'An edition was announced.'},
            'groundingChunkIndices': [0],
          },
        ],
        if (suggestions)
          'searchEntryPoint': {
            'renderedContent':
                '<a href="https://www.google.com/search?q=criterion">Criterion</a>',
          },
      },
    },
  ],
};
http.Response jsonResponse(Object value) =>
    http.Response(jsonEncode(value), 200);

void main() {
  test('mixed research passes only cited claims to the formatter', () {
    const unsupported = 'This unrelated availability claim is unverified.';
    final claude = claudeResearch();
    (claude['content'] as List).add({'type': 'text', 'text': unsupported});
    final claudeResult = FilmResearch.claude(claude);
    expect(claudeResult.text, contains(unsupported));
    expect(claudeResult.context, contains('An edition was announced.'));
    expect(claudeResult.context, isNot(contains(unsupported)));

    final gemini = geminiResearch();
    (gemini['candidates'][0]['content']['parts'] as List).add({
      'text': ' $unsupported',
    });
    // A support with an invalid URL cannot bless a separate paragraph.
    (gemini['candidates'][0]['groundingMetadata']['groundingChunks'] as List)
        .add({
          'web': {'title': 'Invalid', 'uri': 'https://localhost/claim'},
        });
    (gemini['candidates'][0]['groundingMetadata']['groundingSupports'] as List)
        .add({
          'segment': {'text': unsupported},
          'groundingChunkIndices': [1],
        });
    final geminiResult = FilmResearch.gemini(gemini);
    expect(geminiResult.text, contains(unsupported));
    expect(geminiResult.googleSuggestions, isNotNull);
    expect(geminiResult.sources, hasLength(1));
    expect(geminiResult.context, contains('An edition was announced.'));
    expect(geminiResult.context, isNot(contains(unsupported)));
  });

  test(
    'legacy settings remain off, roundtrip and copy preserve opt-in',
    () async {
      final json = const AiConnections(claudeKey: 'TESTPASS123').toJson()
        ..remove('liveResearch');
      expect(AiConnections.fromJson(json).liveResearch, isFalse);
      final next = AiConnections.fromJson(json).copyWith(liveResearch: true);
      expect(AiConnections.fromJson(next.toJson()).liveResearch, isTrue);
      expect(
        next.copyWith(provider: FilmAiProvider.gemini).liveResearch,
        isTrue,
      );
      expect(next.claudeKey, 'TESTPASS123');
      expect(
        () => AiConnections.fromJson({...json, 'liveResearch': 'true'}),
        throwsFormatException,
      );
    },
  );

  for (final provider in [FilmAiProvider.claude, FilmAiProvider.gemini]) {
    test(
      '${provider.name} research is bounded and separate from structured cards',
      () async {
        final store = AiConnectionStore(storage: MemoryStorage());
        await store.save(
          AiConnections(
            provider: provider,
            claudeKey: 'TESTPASS123',
            geminiKey: 'TESTPASS123',
            liveResearch: true,
          ),
        );
        var calls = 0;
        final statuses = <String>[];
        final transport = AiHttp(
          clientFactory: () => MockClient((request) async {
            calls++;
            expect(request.url.scheme, 'https');
            expect(request.followRedirects, isFalse);
            expect(request.body, isNot(contains('TESTPASS123')));
            final body = jsonDecode(request.body) as Map;
            if (calls == 1) {
              expect(body.containsKey('output_config'), isFalse);
              if (provider == FilmAiProvider.claude) {
                expect(request.url.host, 'api.anthropic.com');
                expect(body['tools'], [
                  {
                    'type': 'web_search_20250305',
                    'name': 'web_search',
                    'max_uses': 3,
                  },
                ]);
                return jsonResponse(claudeResearch());
              }
              expect(request.url.host, 'generativelanguage.googleapis.com');
              expect(body['tools'], [
                {'google_search': {}},
              ]);
              expect(
                body['generationConfig'].containsKey('responseFormat'),
                isFalse,
              );
              return jsonResponse(geminiResearch());
            }
            expect(body.containsKey('tools'), isFalse);
            expect(request.body, contains('untrustedResearch'));
            expect(request.body, contains('Criterion'));
            return provider == FilmAiProvider.claude
                ? claudeReply()
                : geminiReply();
          }),
        );
        final result = await ApiFilmChat(
          store,
          http: transport,
          googleResearchReady: () async => true,
        ).send('Latest Criterion releases?', [], onProgress: statuses.add);
        expect(calls, 2);
        expect(result.films.single.title, 'Arrival');
        expect(result.research!.sources.single.uri.host, 'www.criterion.com');
        expect(statuses, [
          'Checking web sources...',
          'Preparing film recommendations...',
        ]);
      },
    );

    for (final change in ['cancel', 'revoke', 'provider']) {
      test(
        '${provider.name} $change during research prevents formatter request',
        () async {
          final store = AiConnectionStore(storage: MemoryStorage());
          final config = AiConnections(
            provider: provider,
            claudeKey: 'TESTPASS123',
            geminiKey: 'TESTPASS123',
            liveResearch: true,
          );
          await store.save(config);
          final entered = Completer<void>();
          final release = Completer<http.Response>();
          var calls = 0;
          final chat = ApiFilmChat(
            store,
            googleResearchReady: () async => true,
            http: AiHttp(
              clientFactory: () => MockClient((_) async {
                calls++;
                entered.complete();
                return release.future;
              }),
            ),
          );
          final rejected = expectLater(
            chat.send('Latest Criterion?', []),
            throwsA(isA<IntegrationException>()),
          );
          await entered.future;
          if (change == 'cancel') {
            await chat.cancel();
          }
          if (change == 'revoke') {
            await store.save(config.copyWith(liveResearch: false));
          }
          if (change == 'provider') {
            await store.save(config.copyWith(provider: FilmAiProvider.codex));
          }
          release.complete(
            jsonResponse(
              provider == FilmAiProvider.claude
                  ? claudeResearch()
                  : geminiResearch(),
            ),
          );
          await rejected;
          expect(calls, 1);
        },
      );
    }

    test(
      '${provider.name} research failure makes no automatic paid retry or cards',
      () async {
        final store = AiConnectionStore(storage: MemoryStorage());
        await store.save(
          AiConnections(
            provider: provider,
            claudeKey: 'TESTPASS123',
            geminiKey: 'TESTPASS123',
            liveResearch: true,
          ),
        );
        var calls = 0;
        final chat = ApiFilmChat(
          store,
          googleResearchReady: () async => true,
          http: AiHttp(
            clientFactory: () => MockClient((_) async {
              calls++;
              return http.Response('TESTPASS123 provider detail', 429);
            }),
          ),
        );
        await expectLater(
          chat.send('Latest releases?', []),
          throwsA(
            isA<IntegrationException>().having(
              (e) => e.message,
              'redacted',
              isNot(contains('TESTPASS123')),
            ),
          ),
        );
        expect(calls, 1);
      },
    );
  }

  test(
    'Gemini unavailable attribution view fails before any paid request',
    () async {
      final store = AiConnectionStore(storage: MemoryStorage());
      await store.save(
        const AiConnections(
          provider: FilmAiProvider.gemini,
          geminiKey: 'TESTPASS123',
          liveResearch: true,
        ),
      );
      var calls = 0;
      final chat = ApiFilmChat(
        store,
        googleResearchReady: () async => false,
        http: AiHttp(
          clientFactory: () => MockClient((_) async {
            calls++;
            return geminiReply();
          }),
        ),
      );
      await expectLater(
        chat.send('Latest releases?', []),
        throwsA(isA<IntegrationException>()),
      );
      expect(calls, 0);
    },
  );

  test(
    'uncited prose cannot become evidence; search errors and partial results fail',
    () {
      final noEvidence = FilmResearch.claude({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': 'Unverified release claim'},
        ],
      });
      expect(noEvidence.hasSources, isFalse);
      expect(noEvidence.context, isNot(contains('Unverified release claim')));
      expect(
        () => FilmResearch.claude({'stop_reason': 'pause_turn', 'content': []}),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => FilmResearch.claude({
          'stop_reason': 'end_turn',
          'content': [
            {
              'type': 'web_search_tool_result',
              'content': {'error_code': 'max_uses_exceeded'},
            },
          ],
        }),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => FilmResearch.claude(claudeResearch(text: 'a' * 16001)),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => FilmResearch.gemini(geminiResearch(suggestions: false)),
        throwsA(isA<IntegrationException>()),
      );
      final uncited = geminiResearch();
      uncited['candidates'][0]['groundingMetadata']['groundingSupports'] = [];
      expect(FilmResearch.gemini(uncited).hasSources, isFalse);
    },
  );

  test(
    'source links reject local, executable, credential and malformed URLs',
    () {
      for (final value in [
        'http://criterion.com',
        'file:///C:/secret',
        'javascript:alert(1)',
        'https://localhost/a',
        'https://127.0.0.1/a',
        'https://[::1]/a',
        'https://0x7f.0.0.1/a',
        'https://www.criterion.com:444/a',
        'https://user:TESTPASS123@criterion.com/a',
        'https://example.local/a',
        'https://criterion.com/a\n',
      ]) {
        expect(ResearchSource.publicUri(value), isNull, reason: value);
      }
      expect(
        ResearchSource.publicUri('https://www.criterion.com/films'),
        isNotNull,
      );
      expect(
        ResearchSuggestions.document('<script>bad()</script>'),
        contains("default-src 'none'"),
      );
      expect(
        ResearchSuggestions.document('<div>Google</div>'),
        contains('<div>Google</div>'),
      );
    },
  );

  testWidgets(
    'research opt-in keeps draft on failed save and persists when retried',
    (tester) async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      await store.save(const AiConnections(provider: FilmAiProvider.claude));
      await tester.pumpWidget(
        MaterialApp(home: AiConnectionsScreen(store: store)),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('ai-live-research'));
      await reveal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      storage.failWrite = true;
      await tester.tap(find.byKey(const Key('save-ai-connections')));
      await tester.pumpAndSettle();
      expect((await store.load()).liveResearch, isFalse);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      storage.failWrite = false;
      await tester.tap(find.byKey(const Key('save-ai-connections')));
      await tester.pumpAndSettle();
      expect((await store.load()).liveResearch, isTrue);
    },
  );

  testWidgets(
    'source panel preserves research, film content and large-text layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ResearchPanel(
                  research: FilmResearch.claude(claudeResearch()),
                  child: const Text('Film cards retained'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Film cards retained'), findsOneWidget);
      expect(find.textContaining('[1] Criterion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Google attribution failure hides the researched reply', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var failures = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResearchPanel(
              research: FilmResearch.gemini(geminiResearch()),
              onUnavailable: () => failures++,
              child: const Text('Researched film cards'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Researched film cards'), findsNothing);
    expect(find.textContaining('researched reply is hidden'), findsOneWidget);
    expect(failures, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'researched chat retains sources, playlist actions and title cards',
    (tester) async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      await store.save(
        const AiConnections(
          provider: FilmAiProvider.claude,
          claudeKey: 'TESTPASS123',
          liveResearch: true,
        ),
      );
      var calls = 0;
      final api = ApiFilmChat(
        store,
        http: AiHttp(
          clientFactory: () => MockClient((_) async {
            calls++;
            return calls == 1 ? jsonResponse(claudeResearch()) : claudeReply();
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FilmChatScreen(
            aiStore: store,
            apiChat: api,
            playlistStore: FilmPlaylistStore(storage: storage),
            onFindReleases: (_) async {},
          ),
        ),
      );
      await settleChat(tester);
      await reveal(tester, field('What would you like to watch?'));
      await tester.enterText(
        field('What would you like to watch?'),
        'Latest Criterion releases',
      );
      await reveal(tester, find.text('Send'));
      await tester.tap(find.text('Send'));
      await settleChat(tester);
      expect(calls, 2);
      expect(find.text('Claude research'), findsOneWidget);
      expect(find.textContaining('[1] Criterion'), findsOneWidget);
      expect(find.text('Arrival (2016)'), findsOneWidget);
      expect(find.text('Add to playlist'), findsOneWidget);
      expect(find.text('Find releases'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
