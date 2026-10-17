import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/chat/ai_connections_screen.dart';
import 'package:zanzibarr/chat/ai_http.dart';
import 'package:zanzibarr/chat/api_film_chat.dart';
import 'package:zanzibarr/chat/film_chat.dart';
import 'package:zanzibarr/chat/film_chat_screen.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:zanzibarr/chat/google_oauth.dart';
import 'package:zanzibarr/integrations/codex_account.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';

import 'film_chat_test.dart' show film, settleChat;
import 'integrations_test.dart' show MemoryStorage;

class _RealHttpOverrides extends HttpOverrides {}

class _DelayedInitialStore extends AiConnectionStore {
  _DelayedInitialStore() : super(storage: MemoryStorage());
  final initial = Completer<AiConnections>();
  bool first = true;
  @override
  Future<AiConnections> load() {
    if (first) {
      first = false;
      return initial.future;
    }
    return super.load();
  }
}

final replyText = jsonEncode({
  'message': 'Try this film.',
  'films': [film.toJson()],
});
http.Response claudeReply() => http.Response(
  jsonEncode({
    'stop_reason': 'end_turn',
    'content': [
      {'type': 'text', 'text': replyText},
    ],
  }),
  200,
);
http.Response geminiReply() => http.Response(
  jsonEncode({
    'candidates': [
      {
        'finishReason': 'STOP',
        'content': {
          'parts': [
            {'text': replyText},
          ],
        },
      },
    ],
  }),
  200,
);
const googleConfig = AiConnections(
  provider: FilmAiProvider.gemini,
  geminiAuthentication: GeminiAuthentication.google,
  googleClientId: 'zanzibarr-test.apps.googleusercontent.com',
  googleClientSecret: 'TESTPASS123',
  googleProject: 'zanzibarr-test',
);
// Matches either labelText (form fields) or hintText (the chat composer,
// which uses a placeholder-only decoration by design, no floating label).
Finder field(String label) => find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      (w.decoration?.labelText == label || w.decoration?.hintText == label),
);
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'secure provider settings preserve failures, reject corruption and clear changed client tokens',
    () async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      expect((await store.load()).provider, FilmAiProvider.codex);
      final original = googleConfig.copyWith(
        googleTokens: GoogleTokens(
          'TESTPASS123',
          'TESTPASS123',
          DateTime.now(),
        ),
      );
      await store.save(original);
      storage.failWrite = true;
      await expectLater(
        store.save(original.copyWith(provider: FilmAiProvider.claude)),
        throwsA(isA<IntegrationException>()),
      );
      expect((await store.load()).provider, FilmAiProvider.gemini);
      expect(
        original
            .copyWith(googleClientId: 'different.apps.googleusercontent.com')
            .googleTokens,
        isNull,
      );
      storage.failWrite = false;
      await store.save(original.copyWith(googleProject: 'different-project'));
      await expectLater(
        store.updateGoogleTokens(original, original.googleTokens!),
        throwsA(isA<IntegrationException>()),
      );
      storage.values[AiConnectionStore.key] = '{broken';
      await expectLater(store.load(), throwsA(isA<IntegrationException>()));
      expect(storage.values[AiConnectionStore.key], '{broken');
    },
  );

  for (final provider in [FilmAiProvider.claude, FilmAiProvider.gemini]) {
    test(
      '${provider.name} uses only its fixed endpoint, header credential and bounded film context',
      () async {
        final store = AiConnectionStore(storage: MemoryStorage());
        await store.save(
          AiConnections(
            provider: provider,
            claudeKey: 'TESTPASS123',
            geminiKey: 'TESTPASS123',
          ),
        );
        var calls = 0;
        final transport = AiHttp(
          clientFactory: () => MockClient((request) async {
            calls++;
            expect(request.url.scheme, 'https');
            expect(request.url.hasQuery, isFalse);
            expect(request.followRedirects, isFalse);
            final body = jsonDecode(request.body) as Map;
            expect(request.body, isNot(contains('TESTPASS123')));
            expect(body.containsKey('tools'), isFalse);
            if (provider == FilmAiProvider.claude) {
              expect(request.url.host, 'api.anthropic.com');
              expect(request.headers['x-api-key'], 'TESTPASS123');
              expect(request.headers.containsKey('x-goog-api-key'), isFalse);
              expect(
                body['output_config']['format']['schema'].toString(),
                isNot(contains('maxLength')),
              );
              expect(
                jsonDecode(
                  body['messages'][0]['content'],
                )['previousConversation'],
                hasLength(10),
              );
              return claudeReply();
            }
            expect(request.url.host, 'generativelanguage.googleapis.com');
            expect(request.headers['x-goog-api-key'], 'TESTPASS123');
            expect(request.headers.containsKey('x-api-key'), isFalse);
            expect(
              body['generationConfig']['responseFormat']['text']['mimeType'],
              'APPLICATION_JSON',
            );
            expect(
              jsonDecode(
                body['contents'][0]['parts'][0]['text'],
              )['previousConversation'],
              hasLength(10),
            );
            return geminiReply();
          }),
        );
        final result = await ApiFilmChat(store, http: transport).send(
          'science fiction',
          List.generate(
            15,
            (_) => const FilmChatMessage(
              'Earlier request',
              FilmReply('A film', [film]),
            ),
          ),
        );
        expect(result.films.single.selection.fallbackQuery, 'Arrival 2016');
        expect(calls, 1);
      },
    );
  }

  test(
    'provider refusals, incomplete and malformed responses never become a playlist',
    () async {
      final store = AiConnectionStore(storage: MemoryStorage());
      await store.save(
        const AiConnections(
          provider: FilmAiProvider.claude,
          claudeKey: 'TESTPASS123',
        ),
      );
      for (final response in [
        http.Response('TESTPASS123 private provider details', 401),
        http.Response('', 302, headers: {'location': 'https://other.example'}),
        http.Response(
          jsonEncode({
            'stop_reason': 'max_tokens',
            'content': [
              {'type': 'text', 'text': replyText},
            ],
          }),
          200,
        ),
        http.Response(
          jsonEncode({
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': 'invalid'},
            ],
          }),
          200,
        ),
      ]) {
        final chat = ApiFilmChat(
          store,
          http: AiHttp(clientFactory: () => MockClient((_) async => response)),
        );
        await expectLater(
          chat.send('films', []),
          throwsA(
            isA<IntegrationException>().having(
              (e) => e.message,
              'sanitized',
              isNot(contains('TESTPASS123')),
            ),
          ),
        );
      }
    },
  );

  test('HTTP size, timeout and cancellation bounds are enforced', () async {
    final big = AiHttp(
      clientFactory: () =>
          MockClient((_) async => http.Response('x' * (512 * 1024 + 1), 200)),
    );
    await expectLater(
      big.post(
        Uri.https('api.anthropic.com', '/v1/messages'),
        service: 'Claude',
      ),
      throwsA(isA<IntegrationException>()),
    );
    final stalled = AiHttp(
      clientFactory: () => MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      stalled.post(
        Uri.https('api.anthropic.com', '/v1/messages'),
        service: 'Claude',
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<IntegrationException>()),
    );
    final pending = stalled.post(
      Uri.https('api.anthropic.com', '/v1/messages'),
      service: 'Claude',
    );
    final assertion = expectLater(
      pending,
      throwsA(isA<IntegrationException>()),
    );
    stalled.cancel();
    await assertion;
  });

  test(
    'Google loopback sign-in rejects wrong state and issuer, exchanges PKCE and closes listener',
    () => HttpOverrides.runWithHttpOverrides(() async {
      Uri? authorization;
      Uri? redirect;
      var exchanges = 0;
      final google = GoogleOAuth(
        http: AiHttp(
          clientFactory: () => MockClient((request) async {
            exchanges++;
            expect(request.url, GoogleOAuth.tokenEndpoint);
            expect(request.followRedirects, isFalse);
            final form = request.bodyFields;
            expect(form['code'], 'TESTPASS123');
            expect(form['client_secret'], 'TESTPASS123');
            expect(
              base64Url
                  .encode(
                    sha256.convert(ascii.encode(form['code_verifier']!)).bytes,
                  )
                  .replaceAll('=', ''),
              authorization!.queryParameters['code_challenge'],
            );
            return http.Response(
              jsonEncode({
                'access_token': 'TESTPASS123',
                'refresh_token': 'TESTPASS123',
                'expires_in': 3600,
                'token_type': 'Bearer',
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(google.cancel);
      final tokens = await google.signIn(googleConfig, (uri) async {
        authorization = uri;
        expect(uri.host, 'accounts.google.com');
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
        expect(redirect!.host, '127.0.0.1');
        final client = HttpClient();
        try {
          for (final query in [
            {'state': 'wrong-state', 'code': 'TESTPASS123'},
            {
              'state': uri.queryParameters['state']!,
              'code': 'TESTPASS123',
              'iss': 'https://other.example',
            },
          ]) {
            final response = await (await client.getUrl(
              redirect!.replace(queryParameters: query),
            )).close();
            expect(response.statusCode, 400);
            await response.drain<void>();
          }
          expect(exchanges, 0);
          final response = await (await client.getUrl(
            redirect!.replace(
              queryParameters: {
                'state': uri.queryParameters['state']!,
                'code': 'TESTPASS123',
              },
            ),
          )).close();
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
        return true;
      });
      expect(tokens.fresh, isTrue);
      expect(exchanges, 1);
      await expectLater(
        Socket.connect(
          redirect!.host,
          redirect!.port,
          timeout: const Duration(milliseconds: 200),
        ),
        throwsA(isA<SocketException>()),
      );
    }, _RealHttpOverrides()),
  );

  test(
    'Google browser failure and cancellation release the login for retry',
    () async {
      final google = GoogleOAuth(timeout: const Duration(milliseconds: 25));
      await expectLater(
        google.signIn(googleConfig, (_) async => false),
        throwsA(isA<IntegrationException>()),
      );
      await expectLater(
        google.signIn(googleConfig, (_) async {
          google.cancel();
          return true;
        }),
        throwsA(isA<IntegrationException>()),
      );
      await expectLater(
        google.signIn(googleConfig, (_) async => true),
        throwsA(isA<IntegrationException>()),
      );
    },
  );

  test(
    'expired Google credentials refresh and persist before Gemini receives the prompt',
    () async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      await store.save(
        googleConfig.copyWith(
          googleTokens: GoogleTokens(
            'TESTPASS123',
            'TESTPASS123',
            DateTime.utc(2020),
          ),
        ),
      );
      var refreshes = 0;
      var prompts = 0;
      final google = GoogleOAuth(
        http: AiHttp(
          clientFactory: () => MockClient((request) async {
            refreshes++;
            expect(request.bodyFields['grant_type'], 'refresh_token');
            return http.Response(
              jsonEncode({
                'access_token': 'TESTPASS123',
                'expires_in': 3600,
                'token_type': 'Bearer',
              }),
              200,
            );
          }),
        ),
      );
      final chat = ApiFilmChat(
        store,
        google: google,
        http: AiHttp(
          clientFactory: () => MockClient((request) async {
            prompts++;
            expect((await store.load()).googleTokens!.fresh, isTrue);
            expect(request.headers['authorization'], 'Bearer TESTPASS123');
            expect(request.headers['x-goog-user-project'], 'zanzibarr-test');
            expect(request.headers.containsKey('x-goog-api-key'), isFalse);
            return geminiReply();
          }),
        ),
      );
      storage.failWrite = true;
      await expectLater(
        chat.send('films', []),
        throwsA(isA<IntegrationException>()),
      );
      expect(prompts, 0);
      storage.failWrite = false;
      await chat.send('films', []);
      await chat.send('more films', []);
      expect(refreshes, 2);
      expect(prompts, 2);
    },
  );

  testWidgets(
    'Claude key setup masks secrets and retains drafts after a failed save',
    (tester) async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      await store.save(const AiConnections(provider: FilmAiProvider.claude));
      await tester.pumpWidget(
        MaterialApp(home: AiConnectionsScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Claude API key'), 'TESTPASS123');
      expect(
        tester.widget<TextField>(field('Claude API key')).obscureText,
        isTrue,
      );
      storage.failWrite = true;
      final save = find.byKey(const Key('save-ai-connections'));
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-connection-error')), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Claude API key')).controller!.text,
        'TESTPASS123',
      );
      expect((await store.load()).claudeKey, isEmpty);
      storage.failWrite = false;
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect((await store.load()).claudeKey, 'TESTPASS123');
    },
  );

  testWidgets(
    'Google OAuth setup fits 360 pixels at 200 percent text and validates missing registration',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AiConnectionStore(storage: MemoryStorage());
      await store.save(
        const AiConnections(
          provider: FilmAiProvider.gemini,
          geminiAuthentication: GeminiAuthentication.google,
        ),
      );
      var launches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AiConnectionsScreen(
              store: store,
              openLink: (_) async {
                launches++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sign in with Google'));
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('ai-connection-error')),
        -300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.textContaining('Desktop OAuth client ID'), findsOneWidget);
      expect(launches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Gemini film cards use existing search and playlists without starting Codex',
    (tester) async {
      final storage = MemoryStorage();
      final store = AiConnectionStore(storage: storage);
      await store.save(
        const AiConnections(
          provider: FilmAiProvider.gemini,
          geminiKey: 'TESTPASS123',
        ),
      );
      var codexStarts = 0;
      final account = CodexAccount(
        start: (_) async {
          codexStarts++;
          throw StateError('unexpected');
        },
      );
      String? query;
      final api = ApiFilmChat(
        store,
        http: AiHttp(
          clientFactory: () => MockClient((_) async => geminiReply()),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FilmChatScreen(
            aiStore: store,
            apiChat: api,
            account: account,
            playlistStore: FilmPlaylistStore(storage: storage),
            onFindReleases: (selection) async =>
                query = selection.fallbackQuery,
          ),
        ),
      );
      await settleChat(tester);
      await reveal(tester, field('What would you like to watch?'));
      await tester.enterText(
        field('What would you like to watch?'),
        'Thoughtful science fiction',
      );
      await reveal(tester, find.text('Send'));
      await tester.tap(find.text('Send'));
      await settleChat(tester);
      await tester.scrollUntilVisible(
        find.text('Find releases'),
        -200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.ensureVisible(find.text('Find releases'));
      await tester.tap(find.text('Find releases'));
      await settleChat(tester);
      expect(query, 'Arrival 2016');
      expect(find.text('Add to playlist'), findsOneWidget);
      expect(codexStarts, 0);
      await tester.scrollUntilVisible(
        find.byKey(const Key('chat-ai-connections')),
        -300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.ensureVisible(find.byKey(const Key('chat-ai-connections')));
      await tester.tap(find.byKey(const Key('chat-ai-connections')));
      await settleChat(tester);
      await tester.tap(find.byKey(const Key('ai-provider')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claude API').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('save-ai-connections')));
      await tester.tap(find.byKey(const Key('save-ai-connections')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await settleChat(tester);
      expect(find.text('Arrival (2016)'), findsNothing);
      expect(find.text('Claude API'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await settleChat(tester);
      account.dispose();
    },
  );
  testWidgets('late initial connection load cannot undo a provider selection', (
    tester,
  ) async {
    final store = _DelayedInitialStore();
    await store.save(const AiConnections(provider: FilmAiProvider.gemini));
    var starts = 0;
    final account = CodexAccount(
      start: (_) async {
        starts++;
        throw StateError('Unexpected Codex start');
      },
    );
    final runtime = IntegrationRuntime(
      store: IntegrationStore(storage: MemoryStorage()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FilmChatScreen(
          aiStore: store,
          runtime: runtime,
          account: account,
          playlistStore: FilmPlaylistStore(storage: MemoryStorage()),
          onFindReleases: (_) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-ai-connections')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await settleChat(tester);
    expect(find.text('Gemini API'), findsOneWidget);
    store.initial.complete(const AiConnections());
    await settleChat(tester);
    expect(find.text('Gemini API'), findsOneWidget);
    expect(starts, 0);
    expect(runtime.settings, isNull);
    await tester.pumpWidget(const SizedBox());
    await settleChat(tester);
    account.dispose();
    runtime.dispose();
  });
}
