import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/chat/film_chat.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/chat/film_chat_screen.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:zanzibarr/integrations/codex_account.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';

import 'integrations_test.dart' show MemoryStorage;

const film = FilmSuggestion(
  title: 'Arrival',
  year: 2016,
  description: 'A linguist works to communicate with visitors.',
  reason: 'Thoughtful science fiction with an emotional story.',
);

class FakeCodex {
  final sent = <Map<String, Object?>>[];
  StreamController<Map<String, dynamic>>? stream;
  bool finish = true;
  bool failTurn = false;
  bool malformed = false;
  Completer<void>? holdThread;
  int threads = 0;
  late final account = CodexAccount(
    start: (_) async {
      final events = StreamController<Map<String, dynamic>>();
      stream = events;
      return CodexRpc(
        events.stream,
        (message) async {
          sent.add(message);
          if (message['id'] == null || message['method'] == null) return;
          Object result = <String, Object>{};
          final method = message['method'];
          if (method == 'account/read') {
            result = {
              'account': {'type': 'chatgpt', 'planType': 'plus'},
            };
          }
          if (method == 'thread/start') {
            threads++;
            await holdThread?.future;
            result = {
              'thread': {'id': 'thread-$threads'},
            };
          }
          if (events.isClosed) return;
          if (method == 'turn/start') {
            final thread = (message['params'] as Map)['threadId'];
            result = {
              'turn': {'id': 'turn-$threads'},
            };
            // Notifications can arrive before the request acknowledgement.
            events.add({
              'method': 'turn/started',
              'params': {
                'threadId': thread,
                'turn': {'id': 'turn-$threads'},
              },
            });
            if (finish) {
              events.add({
                'method': 'item/completed',
                'params': {
                  'threadId': thread,
                  'turnId': 'turn-$threads',
                  'item': {
                    'type': 'agentMessage',
                    'text': malformed
                        ? 'invalid'
                        : jsonEncode({
                            'message': 'Here is a film that fits.',
                            'films': [film.toJson()],
                          }),
                  },
                },
              });
              events.add({
                'method': 'turn/completed',
                'params': {
                  'threadId': thread,
                  'turn': {
                    'id': 'turn-$threads',
                    'status': failTurn ? 'failed' : 'completed',
                  },
                },
              });
            }
          }
          events.add({'id': message['id'], 'result': result});
        },
        () async {
          await events.close();
        },
      );
    },
  );
}

// Matches either labelText (form fields) or hintText (the chat composer,
// which uses a placeholder-only decoration by design, no floating label).
Finder field(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.decoration?.labelText == label ||
          widget.decoration?.hintText == label),
);

// Stream cancellation can complete on the real event queue in Flutter tests.
Future<void> settleChat(WidgetTester tester) async {
  // Each cancellation stage can cross from fake time to the real event queue.
  for (var step = 0; step < 100; step++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('Chat did not settle after cleanup and animation frames.');
}

void main() {
  test(
    'late connection startup cannot restore a disconnected account',
    () async {
      final startup = Completer<CodexRpc>();
      final events = StreamController<Map<String, dynamic>>();
      var closed = 0;
      final rpc = CodexRpc(events.stream, (_) {}, () async {
        closed++;
        await events.close();
      });
      final account = CodexAccount(start: (_) => startup.future);
      final connecting = account.connect('codex.exe');
      await account.disconnect();
      startup.complete(rpc);
      await connecting;
      expect(account.rpc, isNull);
      expect(account.connected, isFalse);
      await rpc.dispose();
      expect(closed, 1);
      account.dispose();
    },
  );

  test('chat account denies server tool and command approvals', () async {
    final fake = FakeCodex();
    addTearDown(fake.account.dispose);
    await fake.account.connect('codex.exe');
    fake.stream!.add({
      'id': 'approval',
      'method': 'item/commandExecution/requestApproval',
      'params': {'command': 'TESTPASS123'},
    });
    await Future<void>.delayed(Duration.zero);
    final reply = fake.sent.singleWhere((m) => m['id'] == 'approval');
    expect(reply['result'], isNull);
    expect((reply['error'] as Map)['code'], -32601);
  });

  test('film suggestions validate limits and never trust AI IDs in search', () {
    final reply = FilmReply.parse(
      jsonEncode({
        'message': 'Try these',
        'films': [
          {...film.toJson(), 'imdbId': 'tt0000000'},
          film.toJson(),
        ],
      }),
    );
    expect(reply.films, hasLength(1));
    expect(reply.films.single.selection.imdbId, isNull);
    expect(reply.films.single.selection.fallbackQuery, 'Arrival 2016');
    expect(
      () => FilmReply.parse(
        jsonEncode({
          'message': 'Try these',
          'films': [
            {...film.toJson(), 'year': -1},
          ],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => FilmReply.parse(
        jsonEncode({
          'message': 'Try these',
          'films': List.filled(13, film.toJson()),
        }),
      ),
      throwsFormatException,
    );
  });

  test(
    'playlist order survives restart and failed writes preserve prior data',
    () async {
      final storage = MemoryStorage();
      final store = FilmPlaylistStore(storage: storage);
      final second = FilmSuggestion(
        title: 'Contact',
        year: 1997,
        description: film.description,
        reason: film.reason,
      );
      final original = FilmPlaylist(
        id: 'list',
        name: 'First contact',
        films: [film, second],
      );
      await store.save([original]);
      await store.save([
        original.copyWith(films: [second, film]),
      ]);
      expect(
        (await FilmPlaylistStore(
          storage: storage,
        ).load()).single.films.first.title,
        'Contact',
      );
      storage.failWrite = true;
      await expectLater(store.save([]), throwsA(isA<IntegrationException>()));
      expect((await store.load()).single.films, hasLength(2));
      storage.values[FilmPlaylistStore.key] = '{"version":99,"playlists":[]}';
      await expectLater(store.load(), throwsA(isA<IntegrationException>()));
      expect(storage.values[FilmPlaylistStore.key], contains('99'));
    },
  );

  test(
    'chat handles early completion and carries bounded follow-up context',
    () async {
      final fake = FakeCodex();
      addTearDown(fake.account.dispose);
      await fake.account.connect('codex.exe');
      final chat = FilmChat(fake.account);
      final first = await chat.send('Films like Arrival', []);
      expect(first.films.single.title, 'Arrival');
      await chat.send('Make it more uplifting', [
        FilmChatMessage('Films like Arrival', first),
      ]);
      final start =
          fake.sent.firstWhere((m) => m['method'] == 'thread/start')['params']
              as Map;
      expect(start['ephemeral'], isTrue);
      expect(start['approvalPolicy'], 'never');
      expect(start['config']['features.shell_tool'], isFalse);
      final turn =
          fake.sent.lastWhere((m) => m['method'] == 'turn/start')['params']
              as Map;
      expect(turn['sandboxPolicy'], {
        'type': 'readOnly',
        'networkAccess': false,
      });
      final context = jsonDecode(turn['input'][0]['text'] as String) as Map;
      expect(context['previousConversation'], hasLength(1));
      expect(context['userMessage'], 'Make it more uplifting');
      expect(
        fake.sent.where((m) => m['method'] == 'thread/unsubscribe'),
        hasLength(2),
      );
    },
  );

  test(
    'failed or malformed completion cannot become a recommendation',
    () async {
      for (final malformed in [false, true]) {
        final fake = FakeCodex()
          ..failTurn = !malformed
          ..malformed = malformed;
        await fake.account.connect('codex.exe');
        await expectLater(
          FilmChat(fake.account).send('Films please', []),
          throwsA(isA<IntegrationException>()),
        );
        expect(fake.account.connected, isFalse);
        fake.account.dispose();
      }
    },
  );

  test(
    'stop before thread acknowledgement closes child and allows reconnect',
    () async {
      final fake = FakeCodex()..holdThread = Completer<void>();
      addTearDown(fake.account.dispose);
      await fake.account.connect('codex.exe');
      final chat = FilmChat(fake.account);
      final response = chat.send('Film ideas', []);
      final check = expectLater(response, throwsA(isA<IntegrationException>()));
      await Future<void>.delayed(Duration.zero);
      await chat.cancel();
      fake.holdThread!.complete();
      await check;
      expect(fake.sent.any((m) => m['method'] == 'turn/start'), isFalse);
      fake.holdThread = null;
      await fake.account.connect('codex.exe');
      expect((await chat.send('Try again', [])).films, hasLength(1));
    },
  );

  test('timeout disconnects without a stuck pending turn', () async {
    final fake = FakeCodex()..finish = false;
    addTearDown(fake.account.dispose);
    await fake.account.connect('codex.exe');
    await expectLater(
      FilmChat(
        fake.account,
        timeout: const Duration(milliseconds: 20),
      ).send('Film ideas', []),
      throwsA(isA<IntegrationException>()),
    );
    expect(fake.account.connected, isFalse);
  });

  testWidgets(
    'chat recommends, saves a playlist and hands a title to release search',
    (tester) async {
      final storage = MemoryStorage();
      final runtime = IntegrationRuntime(
        store: IntegrationStore(storage: storage),
      );
      await runtime.load();
      await runtime.save(
        runtime.settings!.copyWith(codexExecutable: 'codex.exe'),
      );
      final fake = FakeCodex();
      await fake.account.connect('codex.exe');
      String? searched;
      final store = FilmPlaylistStore(storage: storage);
      await tester.pumpWidget(
        MaterialApp(
          home: FilmChatScreen(
            aiStore: AiConnectionStore(storage: storage),
            runtime: runtime,
            account: fake.account,
            playlistStore: store,
            onFindReleases: (selection) async {
              searched = selection.fallbackQuery;
            },
          ),
        ),
      );
      await settleChat(tester);
      await tester.scrollUntilVisible(
        field('What would you like to watch?'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.enterText(
        field('What would you like to watch?'),
        'Thoughtful sci-fi',
      );
      // Rebuild so the composer's ValueListenableBuilder picks up the new
      // text before Send is tapped; otherwise onPressed is still the stale
      // disabled callback from before text existed and the tap is a no-op.
      await tester.pump();
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pump(const Duration(seconds: 1));
      await settleChat(tester);
      await tester.scrollUntilVisible(
        find.text('Arrival (2016)'),
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
      expect(searched, 'Arrival 2016');
      await tester.ensureVisible(find.text('Add to playlist'));
      await tester.tap(find.text('Add to playlist'));
      await settleChat(tester);
      await tester.tap(find.text('New playlist'));
      await settleChat(tester);
      await tester.enterText(field('Playlist name'), 'Sci-fi night');
      storage.failWrite = true;
      await tester.tap(find.text('Save'));
      await settleChat(tester);
      expect(field('Playlist name'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Playlist name')).controller!.text,
        'Sci-fi night',
      );
      storage.failWrite = false;
      await tester.tap(find.text('Save'));
      await settleChat(tester);
      expect((await store.load()).single.name, 'Sci-fi night');
      await tester.tap(find.text('Playlists'));
      await settleChat(tester);
      expect(find.text('Sci-fi night'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await settleChat(tester);
      fake.account.dispose();
      await runtime.shutdown();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat setup fits a narrow screen at large text and keeps failed drafts',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final runtime = IntegrationRuntime(
        store: IntegrationStore(storage: storage),
      );
      await runtime.load();
      await runtime.save(
        runtime.settings!.copyWith(codexExecutable: 'codex.exe'),
      );
      final fake = FakeCodex()..failTurn = true;
      await fake.account.connect('codex.exe');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: FilmChatScreen(
              aiStore: AiConnectionStore(storage: storage),
              runtime: runtime,
              account: fake.account,
              playlistStore: FilmPlaylistStore(storage: storage),
              onFindReleases: (_) async {},
            ),
          ),
        ),
      );
      await settleChat(tester);
      await tester.scrollUntilVisible(
        field('What would you like to watch?'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.enterText(
        field('What would you like to watch?'),
        'Keep this request',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pump(const Duration(seconds: 1));
      await settleChat(tester);
      expect(
        tester
            .widget<TextField>(field('What would you like to watch?'))
            .controller!
            .text,
        'Keep this request',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settleChat(tester);
      fake.account.dispose();
      await runtime.shutdown();
    },
  );
}
