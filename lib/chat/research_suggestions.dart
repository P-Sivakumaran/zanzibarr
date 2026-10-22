import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'film_research.dart';

/// Displays the provider's suggestion markup without giving it script, file,
/// frame or request authority. User-selected public links open externally.
class ResearchSuggestions extends StatefulWidget {
  const ResearchSuggestions({
    super.key,
    required this.html,
    required this.onUnavailable,
    required this.onReady,
  });
  final String html;
  final VoidCallback onUnavailable, onReady;
  static Future<bool> available() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.fuchsia) {
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.windows) return true;
    try {
      return await WebViewEnvironment.getAvailableVersion() != null;
    } catch (_) {
      return false;
    }
  }

  static String document(String html) =>
      '<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; img-src data: https://www.gstatic.com; base-uri \'none\'; form-action \'none\'; frame-src \'none\'; object-src \'none\'"></head><body>$html</body></html>';

  @override
  State<ResearchSuggestions> createState() => _ResearchSuggestionsState();
}

class _ResearchSuggestionsState extends State<ResearchSuggestions> {
  WebViewEnvironment? _environment;
  Timer? _timer;
  late final Future<bool> _ready = _prepare();
  Future<bool> _prepare() async {
    if (!await ResearchSuggestions.available()) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final directory = await getApplicationSupportDirectory();
        final environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: '${directory.path}/research-suggestions-webview',
          ),
        );
        if (!mounted) {
          await environment.dispose();
          return false;
        }
        _environment = environment;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted) widget.onUnavailable();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_environment?.dispose().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _open(WebUri? url, bool? gesture) async {
    final uri = ResearchSource.publicUri(url?.toString());
    if (!mounted || gesture != true || uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.data != true) {
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onUnavailable();
          });
        }
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return SizedBox(
        height: 220,
        child: Semantics(
          label: 'Google Search suggestions',
          child: InAppWebView(
            webViewEnvironment: _environment,
            initialData: InAppWebViewInitialData(
              data: ResearchSuggestions.document(widget.html),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: false,
              javaScriptCanOpenWindowsAutomatically: false,
              supportMultipleWindows: true,
              useShouldOverrideUrlLoading: true,
              allowFileAccess: false,
              allowFileAccessFromFileURLs: false,
              allowUniversalAccessFromFileURLs: false,
              mediaPlaybackRequiresUserGesture: true,
              isInspectable: false,
            ),
            onLoadStop: (_, _) {
              if (mounted) widget.onReady();
              _timer?.cancel();
            },
            onReceivedError: (_, request, _) {
              if (request.isForMainFrame == true) widget.onUnavailable();
            },
            onPermissionRequest: (_, request) async => PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.DENY,
            ),
            shouldOverrideUrlLoading: (_, action) async {
              final url = action.request.url;
              if (url?.toString() == 'about:blank' &&
                  action.hasGesture != true) {
                return NavigationActionPolicy.ALLOW;
              }
              await _open(url, action.hasGesture);
              return NavigationActionPolicy.CANCEL;
            },
            onCreateWindow: (_, action) async {
              await _open(action.request.url, action.hasGesture);
              return false;
            },
          ),
        ),
      );
    },
  );
}
