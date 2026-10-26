import '../editions/edition_paths.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../settings/enrichment_settings.dart';
import 'title_trailer.dart';
import 'trailer_navigation.dart';

/// No YouTube connection or platform view until the viewer chooses to load it.
class TrailerPanel extends StatefulWidget {
  const TrailerPanel({
    super.key,
    this.trailer,
    this.loading = false,
    this.configured = false,
    this.playerBuilder,
    this.onConfigured,
  });
  final TitleTrailer? trailer;
  final VoidCallback? onConfigured;
  final bool loading, configured;
  final Widget Function(BuildContext, TitleTrailer, VoidCallback)?
  playerBuilder;
  @override
  State<TrailerPanel> createState() => _TrailerPanelState();
}

class _TrailerPanelState extends State<TrailerPanel> {
  bool _open = false, _failed = false;
  @override
  void didUpdateWidget(TrailerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailer?.key != widget.trailer?.key) {
      _open = false;
      _failed = false;
    }
  }

  bool get _supported =>
      !kIsWeb &&
      defaultTargetPlatform != TargetPlatform.linux &&
      defaultTargetPlatform != TargetPlatform.fuchsia;
  Future<void> _external() async {
    try {
      if (await launchUrl(
        widget.trailer!.watchUri,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The trailer could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailer = widget.trailer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trailer', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (widget.loading && trailer == null)
          const Text('Checking for an official trailer...')
        else if (trailer == null) ...[
          Text(
            widget.configured
                ? 'No official trailer is available from this source.'
                : 'Connect TMDB in Additional metadata sources to find official trailers.',
          ),
          if (!widget.configured)
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EnrichmentSettingsScreen(),
                  ),
                );
                if (mounted) widget.onConfigured?.call();
              },
              child: const Text('Set up trailers'),
            ),
        ] else ...[
          Text(
            '${trailer.teaser ? 'Official teaser' : 'Official trailer'} / YouTube, via TMDB',
          ),
          const SizedBox(height: 8),
          if (_open && !_failed)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, bounds) => SizedBox(
                  height: math.max(200, bounds.maxWidth * 9 / 16),
                  child:
                      widget.playerBuilder?.call(context, trailer, () {
                        if (mounted) setState(() => _failed = true);
                      }) ??
                      _EmbeddedTrailer(
                        key: ValueKey(trailer.key),
                        trailer: trailer,
                        onError: () {
                          if (mounted) setState(() => _failed = true);
                        },
                      ),
                ),
              ),
            )
          else ...[
            if (_failed)
              const Text(
                'Embedded playback is unavailable. You can open this trailer on YouTube.',
              ),
            if (_supported || widget.playerBuilder != null)
              FilledButton.tonalIcon(
                onPressed: () => setState(() {
                  _failed = false;
                  _open = true;
                }),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  _failed ? 'Retry embedded trailer' : 'Load trailer',
                ),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_open)
                TextButton(
                  onPressed: () => setState(() {
                    _open = false;
                    _failed = false;
                  }),
                  child: const Text('Close trailer'),
                ),
              TextButton.icon(
                onPressed: _external,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open on YouTube'),
              ),
            ],
          ),
          const Text(
            'Loads YouTube when opened. Trailers may reveal story details.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _EmbeddedTrailer extends StatefulWidget {
  const _EmbeddedTrailer({
    super.key,
    required this.trailer,
    required this.onError,
  });
  final TitleTrailer trailer;
  final VoidCallback onError;
  @override
  State<_EmbeddedTrailer> createState() => _EmbeddedTrailerState();
}

class _EmbeddedTrailerState extends State<_EmbeddedTrailer>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  WebViewEnvironment? _environment;
  Timer? _deadline;
  late final Future<bool> _available = _checkRuntime();
  Future<bool> _checkRuntime() async {
    if (defaultTargetPlatform != TargetPlatform.windows) return true;
    try {
      final available = await WebViewEnvironment.getAvailableVersion() != null;
      if (!available) {
        _deadline?.cancel();
        return false;
      }
      final directory = await editionSupportDirectory();
      final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: '${directory.path}/trailer-webview',
        ),
      );
      if (!mounted) {
        await environment.dispose();
        return false;
      }
      _environment = environment;
      return true;
    } catch (_) {
      _deadline?.cancel();
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deadline = Timer(const Duration(seconds: 25), widget.onError);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller?.pauseAllMediaPlayback().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_environment?.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _available,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data != true) {
        return const Center(
          child: Text(
            'Install Microsoft Edge WebView2 Runtime to play trailers here. Use Open on YouTube meanwhile.',
          ),
        );
      }
      return InAppWebView(
        webViewEnvironment: _environment,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: true,
          allowsInlineMediaPlayback: true,
          useShouldOverrideUrlLoading: true,
          javaScriptCanOpenWindowsAutomatically: false,
          supportMultipleWindows: false,
        ),
        onWebViewCreated: (controller) async {
          _controller = controller;
          try {
            await navigateTrailer(
              controller,
              widget.trailer,
              platform: defaultTargetPlatform,
            );
          } catch (_) {
            if (mounted) widget.onError();
          }
        },
        onLoadStop: (_, url) {
          if (url?.host == widget.trailer.embedUri.host &&
              url?.path == widget.trailer.embedUri.path) {
            _deadline?.cancel();
          }
        },
        onReceivedError: (_, request, _) {
          if (request.isForMainFrame == true) widget.onError();
        },
        onReceivedHttpError: (_, request, response) {
          if (request.isForMainFrame == true &&
              (response.statusCode ?? 0) >= 400) {
            widget.onError();
          }
        },
        onPermissionRequest: (_, request) async => PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.DENY,
        ),
        onCreateWindow: (_, _) async => false,
        shouldOverrideUrlLoading: (_, action) async {
          if (!action.isForMainFrame) {
            return NavigationActionPolicy.ALLOW;
          }
          final uri = action.request.url;
          // Keep the embedded surface on its selected trailer; external viewing is explicit.
          return uri != null &&
                  uri.scheme == 'https' &&
                  uri.host == 'www.youtube-nocookie.com' &&
                  uri.path == '/embed/${widget.trailer.key}'
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL;
        },
      );
    },
  );
}
