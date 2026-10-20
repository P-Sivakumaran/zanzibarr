import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zanzibarr/metadata/title_trailer.dart';
import 'package:zanzibarr/metadata/trailer_navigation.dart';

/// Opt-in live WebView2 diagnosis, isolated from normal app data and credentials.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'live YouTube embed reports no video player configuration error',
    (tester) async {
      const audit = String.fromEnvironment('TRAILER_AUDIT_DIR');
      const mode = String.fromEnvironment(
        'TRAILER_PROBE_MODE',
        defaultValue: 'direct',
      );
      expect(audit, isNotEmpty);
      await Directory(audit).create(recursive: true);
      final runtime = await WebViewEnvironment.getAvailableVersion();
      expect(
        runtime,
        isNotNull,
        reason: 'WebView2 Runtime is required for this live check',
      );
      final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: '$audit/profile-$mode',
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await environment.dispose();
      });
      InAppWebViewController? controller;
      final loaded = Completer<void>();
      final errors = <String>[];
      const trailer = TitleTrailer(
        key: 'M7lc1UVf-VE',
        name: 'YouTube API example',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: InAppWebView(
                webViewEnvironment: environment,
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: true,
                  allowsInlineMediaPlayback: true,
                  useShouldOverrideUrlLoading: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  supportMultipleWindows: false,
                ),
                onWebViewCreated: (value) async {
                  controller = value;
                  await navigateTrailer(
                    value,
                    trailer,
                    platform: TargetPlatform.windows,
                  );
                },
                onLoadStop: (_, url) {
                  if (url?.host == trailer.embedUri.host &&
                      !loaded.isCompleted) {
                    loaded.complete();
                  }
                },
                onReceivedError: (_, request, error) {
                  if (request.isForMainFrame == true) {
                    errors.add(error.description);
                  }
                },
                shouldOverrideUrlLoading: (_, action) async {
                  if (!action.isForMainFrame) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  final uri = action.request.url;
                  return uri != null &&
                          uri.scheme == 'https' &&
                          uri.host == 'www.youtube-nocookie.com' &&
                          uri.path == '/embed/${trailer.key}'
                      ? NavigationActionPolicy.ALLOW
                      : NavigationActionPolicy.CANCEL;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await loaded.future.timeout(const Duration(seconds: 45));
        await Future<void>.delayed(const Duration(seconds: 12));
      });
      final browser = controller!;
      final raw = await browser.evaluateJavascript(
        source:
            r'''JSON.stringify({referrer: document.referrer, origin: location.origin, error: document.querySelector('.ytp-error-content-wrap')?.innerText || '', player: !!document.querySelector('#movie_player'), state: document.querySelector('#movie_player')?.getPlayerState?.(), title: document.title})''',
      );
      final page = raw is String ? jsonDecode(raw) : raw;
      await File('$audit/native-$mode.json').writeAsString(
        jsonEncode({'runtime': runtime, 'page': page, 'loadErrors': errors}),
      );
      await browser.callDevToolsProtocolMethod(
        methodName: 'Runtime.evaluate',
        parameters: {
          'expression':
              "document.querySelector('#movie_player').mute(); document.querySelector('#movie_player').playVideo();",
          'userGesture': true,
        },
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 5)),
      );
      final playbackRaw = await browser.evaluateJavascript(
        source:
            "JSON.stringify({time:document.querySelector('video')?.currentTime,width:document.querySelector('video')?.videoWidth,state:document.querySelector('#movie_player')?.getPlayerState?.()})",
      );
      final playback = playbackRaw is String
          ? jsonDecode(playbackRaw)
          : playbackRaw;
      await File(
        '$audit/native-$mode-playback.json',
      ).writeAsString(jsonEncode(playback));
      expect(playback['state'], 1);
      expect(playback['time'], greaterThan(0));
      expect(playback['width'], greaterThan(0));
      expect(errors, isEmpty);
      expect(page['referrer'], trailerAppReferrer);
      expect(page['player'], isTrue);
      expect(
        page['error'],
        isEmpty,
        reason: 'Native YouTube player error: ${page['error']}',
      );
    },
    skip: !const bool.fromEnvironment('LIVE_TRAILER_TEST'),
  );
}
