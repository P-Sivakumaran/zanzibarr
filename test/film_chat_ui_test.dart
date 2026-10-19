import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/chat/film_chat_screen.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'package:zanzibarr/integrations/codex_account.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/settings/ui_preferences.dart';

import 'film_chat_test.dart' show FakeCodex, film, settleChat;
import 'integrations_test.dart' show MemoryStorage;
import 'tv_discovery_test.dart' as tv;

final _screenshots = Platform.environment['GENERATE_CHAT_SCREENSHOTS'] == '1';
const _promptKey = Key('chat-prompt');
const _sendKey = Key('chat-send');

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool primary = false,
  bool meta = false,
  bool shift = false,
}) async {
  if (primary) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    await tester.sendKeyEvent(key);
  } finally {
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    if (primary) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
}

Future<void> _fonts() async {
  if (!_screenshots) return;
  final loader = FontLoader('DiscoveryPreview')
    ..addFont(rootBundle.load('assets/fonts/subtitle.ttf'));
  await loader.load();
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
      '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await candidate.exists()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(candidate.readAsBytes().then(ByteData.sublistView));
      await icons.load();
      return;
    }
    directory = directory.parent;
  }
  throw StateError('Flutter Material icons font was not found');
}

// A CodexRpc that answers account/read with a non-chatgpt account and
// echoes an empty result for anything else, so a caller awaiting it
// resolves quickly without ever reporting a connected account.
CodexRpc _harmlessRpc() {
  final events = StreamController<Map<String, dynamic>>();
  return CodexRpc(events.stream, (message) {
    final id = message['id'];
    if (id == null) return;
    Object result = <String, Object>{};
    if (message['method'] == 'account/read') {
      result = {
        'account': {'type': 'none'},
      };
    }
    if (!events.isClosed) events.add({'id': id, 'result': result});
  }, () async => events.close());
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_screenshots) {
    await tester.pump(const Duration(milliseconds: 350));
    await expectLater(
      name == 'shortcuts-large-text'
          ? find.byType(MaterialApp)
          : find.byKey(const Key('discovery-preview')),
      matchesGoldenFile('../docs/screenshots/film-chat-$name.png'),
    );
  }
}

Future<
  ({MemoryStorage storage, CodexAccount account, IntegrationRuntime runtime})
>
_mount(
  WidgetTester tester, {
  CodexAccount? account,
  FakeCodex? fake,
  void Function(String kind)? onSearchKind,
  MemoryStorage? storage,
  bool connected = true,
  Size size = const Size(1280, 800),
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  ThemeMode mode = ThemeMode.dark,
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final memory = storage ?? MemoryStorage();
  final runtime = IntegrationRuntime(store: IntegrationStore(storage: memory));
  await runtime.load();
  await runtime.save(runtime.settings!.copyWith(codexExecutable: 'codex.exe'));
  final actualAccount = account ?? (fake ?? FakeCodex()).account;
  if (connected) await actualAccount.connect('codex.exe');
  final preferences = UiPreferencesController(UiPreferencesStore())
    ..themeMode = mode;
  await tester.pumpWidget(
    ZanzibarrApp(
      uiPreferences: preferences,
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return RepaintBoundary(
            key: const Key('discovery-preview'),
            child: Theme(
              data: _screenshots
                  ? theme.copyWith(
                      platform: platform,
                      textTheme: theme.textTheme.apply(
                        fontFamily: 'DiscoveryPreview',
                      ),
                    )
                  : theme.copyWith(platform: platform),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: FilmChatScreen(
                    account: actualAccount,
                    runtime: runtime,
                    aiStore: AiConnectionStore(storage: memory),
                    playlistStore: FilmPlaylistStore(storage: memory),
                    onFindReleases: (selection) async =>
                        onSearchKind?.call(selection.kind),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await settleChat(tester);
    actualAccount.dispose();
    preferences.dispose();
    await runtime.shutdown();
  });
  return (storage: memory, account: actualAccount, runtime: runtime);
}

void main() {
  setUpAll(_fonts);

  testWidgets(
    'Enter sends TV recommendations and Find releases uses TV search',
    (tester) async {
      final fake = FakeCodex()..suggestions = const [tv.show];
      String? searched;
      await _mount(tester, fake: fake, onSearchKind: (kind) => searched = kind);
      await tester.enterText(find.byKey(_promptKey), 'TV shows with a mystery');
      await _key(tester, LogicalKeyboardKey.enter);
      await settleChat(tester);
      expect(find.text('Severance (2022)'), findsOneWidget);
      expect(find.text('TV show'), findsOneWidget);
      expect(fake.threads, 1);
      expect(
        tester.widget<TextField>(find.byKey(_promptKey)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.ensureVisible(find.text('Find releases'));
      await tester.tap(find.text('Find releases'));
      await settleChat(tester);
      expect(searched, 'tv');
      await _shot(tester, 'tv-recommendation');
      await tester.ensureVisible(find.text('Add to playlist'));
      await tester.tap(find.text('Add to playlist'));
      await settleChat(tester);
      await tester.tap(find.text('New playlist'));
      await settleChat(tester);
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Playlist name',
      );
      await tester.enterText(name, 'TV to try');
      await tester.tap(find.text('Save'));
      await settleChat(tester);
      await tester.tap(find.text('Playlists'));
      await settleChat(tester);
      await tester.tap(find.text('TV to try'));
      await settleChat(tester);
      expect(find.text('TV show'), findsOneWidget);
      expect(find.text('Severance (2022)'), findsOneWidget);
    },
  );

  testWidgets('Shift Enter inserts a newline and Cmd Enter sends once', (
    tester,
  ) async {
    final fake = FakeCodex();
    await _mount(tester, fake: fake);
    await tester.enterText(find.byKey(_promptKey), 'First line');
    await tester.pump(const Duration(milliseconds: 600));
    await _key(tester, LogicalKeyboardKey.enter, shift: true);
    await tester.pump();
    final controller = tester
        .widget<TextField>(find.byKey(_promptKey))
        .controller!;
    expect(controller.text, 'First line\n');
    expect(fake.threads, 0);
    await tester.pump(const Duration(milliseconds: 600));
    await _key(tester, LogicalKeyboardKey.keyZ, primary: true);
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.text, 'First line');
    await _key(tester, LogicalKeyboardKey.keyY, primary: true);
    await tester.pump();
    expect(controller.text, 'First line\n');
    await _key(tester, LogicalKeyboardKey.enter, meta: true);
    await settleChat(tester);
    expect(fake.threads, 1);
    expect(controller.text, isEmpty);
  });

  testWidgets('Enter commits IME composition without starting a request', (
    tester,
  ) async {
    final fake = FakeCodex();
    await _mount(tester, fake: fake);
    await tester.enterText(find.byKey(_promptKey), '草稿');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '草稿',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    expect(fake.threads, 0);
    expect(
      tester.widget<TextField>(find.byKey(_promptKey)).controller!.text,
      contains('草稿'),
    );
  });

  testWidgets(
    'macOS command shortcuts focus the composer and native selection',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _mount(tester, platform: TargetPlatform.macOS);
        await _key(tester, LogicalKeyboardKey.keyL, meta: true);
        await settleChat(tester);
        await tester.enterText(find.byKey(_promptKey), 'Mac draft');
        await _key(tester, LogicalKeyboardKey.keyA, meta: true);
        final field = tester.widget<TextField>(find.byKey(_promptKey));
        expect(
          field.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 9),
        );
        await _key(tester, LogicalKeyboardKey.keyN, meta: true);
        await settleChat(tester);
        expect(field.controller!.text, 'Mac draft');
        await _key(tester, LogicalKeyboardKey.slash, meta: true);
        await tester.pumpAndSettle();
        expect(find.text('Enter or ⌘+Enter'), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('Escape stops a reply and preserves the draft', (tester) async {
    final fake = FakeCodex()..finish = false;
    await _mount(tester, fake: fake);
    await tester.enterText(find.byKey(_promptKey), 'Keep this TV request');
    await _key(tester, LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stop'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    await settleChat(tester);
    expect(find.text('Stop'), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(_promptKey)).controller!.text,
      'Keep this TV request',
    );
  });

  testWidgets(
    'chat navigation shortcuts switch tabs, keep drafts and expose help',
    (tester) async {
      await _mount(tester);
      await tester.enterText(find.byKey(_promptKey), 'First request');
      await _key(tester, LogicalKeyboardKey.enter);
      await settleChat(tester);
      await tester.enterText(find.byKey(_promptKey), 'Keep this draft');
      await _key(tester, LogicalKeyboardKey.digit2, primary: true);
      await settleChat(tester);
      expect(find.text('Your playlists'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.keyL, primary: true);
      await settleChat(tester);
      expect(
        tester.widget<TextField>(find.byKey(_promptKey)).focusNode!.hasFocus,
        isTrue,
      );
      await _key(tester, LogicalKeyboardKey.keyN, primary: true);
      await settleChat(tester);
      expect(find.text('Arrival (2016)'), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(_promptKey)).controller!.text,
        'Keep this draft',
      );
      await _key(tester, LogicalKeyboardKey.slash, primary: true);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('New chat (keeps your draft)'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await _key(tester, LogicalKeyboardKey.comma, primary: true);
      await tester.pumpAndSettle();
      expect(find.text('AI connections'), findsOneWidget);
      await tester.pageBack();
      await settleChat(tester);
      expect(
        tester.widget<TextField>(find.byKey(_promptKey)).controller!.text,
        'Keep this draft',
      );
    },
  );

  testWidgets(
    'native select copy cut paste undo redo and Tab remain available',
    (tester) async {
      var clipboard = '';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _mount(tester);
      await tester.enterText(find.byKey(_promptKey), 'A television draft');
      await tester.pump(const Duration(milliseconds: 600));
      final field = tester.widget<TextField>(find.byKey(_promptKey));
      await _key(tester, LogicalKeyboardKey.keyA, primary: true);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 18),
      );
      await _key(tester, LogicalKeyboardKey.keyC, primary: true);
      await tester.pump();
      expect(clipboard, 'A television draft');
      await _key(tester, LogicalKeyboardKey.keyX, primary: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(field.controller!.text, isEmpty);
      await _key(tester, LogicalKeyboardKey.keyV, primary: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(field.controller!.text, 'A television draft');
      await _key(tester, LogicalKeyboardKey.keyZ, primary: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(field.controller!.text, isEmpty);
      await _key(tester, LogicalKeyboardKey.keyZ, primary: true, shift: true);
      await tester.pump();
      expect(field.controller!.text, 'A television draft');
      await _key(tester, LogicalKeyboardKey.tab);
      await tester.pump();
      expect(field.focusNode!.hasFocus, isFalse);
      await _key(tester, LogicalKeyboardKey.tab, shift: true);
      await tester.pump();
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await _key(tester, LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'connection failure has a retry, hides the path, and keeps Send disabled',
    (tester) async {
      var attempts = 0;
      final account = CodexAccount(
        start: (_) async {
          attempts++;
          throw const IntegrationException(
            'Could not read the Codex account. Codex request failed or timed out.',
          );
        },
      );
      await _mount(tester, account: account, connected: false);
      expect(find.text('Retry connection'), findsOneWidget);
      expect(find.text('Change provider'), findsOneWidget);
      expect(find.text('Codex executable path'), findsNothing);
      expect(tester.getRect(find.byKey(_promptKey)).bottom, lessThan(800));
      await tester.enterText(find.byKey(_promptKey), 'Keep my movie request');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(_sendKey)).onPressed,
        isNull,
      );
      await _shot(tester, 'connection-error');
      await tester.tap(find.text('Retry connection'));
      await settleChat(tester);
      expect(attempts, 2);
      expect(
        tester.widget<TextField>(find.byKey(_promptKey)).controller!.text,
        'Keep my movie request',
      );
      await tester.tap(find.byTooltip('Advanced connection settings'));
      await settleChat(tester);
      expect(find.text('Codex executable path'), findsOneWidget);
      expect(find.byKey(const Key('chat-connection-details')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ideas focus the composer and keyboard send leaves it anchored', (
    tester,
  ) async {
    await _mount(tester);
    expect(tester.widget<FilledButton>(find.byKey(_sendKey)).onPressed, isNull);
    await tester.tap(find.text('Crime & mystery'));
    await tester.pump();
    final prompt = tester.widget<TextField>(find.byKey(_promptKey));
    expect(prompt.controller!.text, 'Slow-burn crime films from the 1970s');
    expect(prompt.focusNode!.hasFocus, isTrue);
    expect(
      tester.widget<FilledButton>(find.byKey(_sendKey)).onPressed,
      isNotNull,
    );
    await _shot(tester, 'ready');
    final before = tester.getRect(find.byKey(const Key('chat-composer')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleChat(tester);
    expect(find.text('Arrival (2016)'), findsOneWidget);
    expect(prompt.controller!.text, isEmpty);
    await tester.drag(
      find.byKey(const Key('chat-content-scroll')),
      const Offset(0, -500),
    );
    await settleChat(tester);
    // The composer lives outside the scrollable, so scrolling the message
    // list must not move it. Compared with a small tolerance rather than
    // exact equality: sub-pixel text-layout rounding can shift this by a
    // fraction of a logical pixel without any visible effect.
    final after = tester.getRect(find.byKey(const Key('chat-composer')));
    expect(after.left, closeTo(before.left, 1));
    expect(after.top, closeTo(before.top, 1));
    expect(after.right, closeTo(before.right, 1));
    expect(after.bottom, closeTo(before.bottom, 1));
    await _shot(tester, 'recommendation');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text and RTL fit a narrow viewport with the keyboard open',
    (tester) async {
      await _mount(
        tester,
        size: const Size(360, 850),
        scale: 2,
        direction: TextDirection.rtl,
      );
      await tester.scrollUntilVisible(
        find.byKey(_promptKey),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('chat-content-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(find.byKey(_promptKey), 'A thoughtful film');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.ensureVisible(find.byKey(_sendKey));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_sendKey)).right,
        lessThanOrEqualTo(360),
      );
      expect(tester.takeException(), isNull);
      await _key(tester, LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shot(tester, 'shortcuts-large-text');
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('light theme and short windows retain a usable composer', (
    tester,
  ) async {
    await _mount(tester, size: const Size(720, 480), mode: ThemeMode.light);
    await tester.scrollUntilVisible(
      find.byKey(_promptKey),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('chat-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.byKey(_promptKey), 'An uplifting movie');
    await tester.ensureVisible(find.byKey(_sendKey));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(_sendKey)).onPressed,
      isNotNull,
    );
    await _shot(tester, 'light-compact');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing provider cancels a pending account check without late startup',
    (tester) async {
      final startup = Completer<CodexRpc>();
      var starts = 0;
      final account = CodexAccount(
        start: (_) {
          starts++;
          // The screen automatically re-checks the connection after the
          // user returns from AI connections, so `start` is called again.
          // Only the first (abandoned) check should hang on the
          // externally-controlled completer below; the second gets its
          // own independent, harmless RPC so it can resolve normally
          // instead of racing the first call for the same CodexRpc.
          return starts == 1 ? startup.future : Future.value(_harmlessRpc());
        },
      );
      await _mount(tester, account: account, connected: false);
      await tester.tap(find.byKey(const Key('chat-ai-connections')));
      await tester.pumpAndSettle();
      expect(find.text('AI connections'), findsOneWidget);
      final events = StreamController<Map<String, dynamic>>();
      var requests = 0;
      startup.complete(
        CodexRpc(events.stream, (_) => requests++, () async {
          await events.close();
        }),
      );
      await settleChat(tester);
      expect(requests, 0);
      expect(account.connected, isFalse);
      expect(tester.takeException(), isNull);
      // Close the pushed AI connections route so it doesn't linger into
      // teardown/the next test as an unpopped, suspended Navigator.push.
      await tester.pageBack();
      await settleChat(tester);
    },
  );

  testWidgets(
    'playlist deletion requires confirmation and stale edits preserve newer lists',
    (tester) async {
      final storage = MemoryStorage();
      final store = FilmPlaylistStore(storage: storage);
      final original = FilmPlaylist(
        id: 'first',
        name: 'Movie night',
        films: [film],
      );

      await store.save([original]);

      await _mount(tester, storage: storage);

      await tester.tap(find.text('Playlists'));
      await settleChat(tester);
      await tester.tap(find.text('Movie night'));
      await settleChat(tester);

      await tester.tap(find.text('Delete playlist'));
      await settleChat(tester);
      expect(find.text('Delete playlist?'), findsOneWidget);

      expect((await store.load()).single.id, 'first');
      await tester.tap(find.text('Keep playlist'));
      await settleChat(tester);
      await store.save([
        original,
        FilmPlaylist(id: 'second', name: 'Newer list', films: []),
      ]);

      await tester.tap(find.text('Rename'));
      await settleChat(tester);
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Playlist name',
      );
      await tester.enterText(name, 'My draft name');

      await tester.tap(find.text('Save'));
      await settleChat(tester);
      expect(name, findsOneWidget);
      expect(tester.widget<TextField>(name).controller!.text, 'My draft name');
      // A SnackBar transiently echoes the same message as a toast alongside
      // the persistent inline banner, so match the banner by key rather
      // than by text (which briefly matches both).
      expect(find.byKey(const Key('playlist-error')), findsOneWidget);
      expect((await store.load()).map((p) => p.id), ['first', 'second']);

      await tester.tap(find.text('Reload saved lists'));
      await settleChat(tester);
      expect(tester.widget<TextField>(name).controller!.text, 'My draft name');
      await tester.tap(find.text('Save'));
      await settleChat(tester);
      expect((await store.load()).first.name, 'My draft name');
      expect(find.text('Newer list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
