import 'edition_config.dart';
import 'playback_lock.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef DeviceAuthenticator = Future<bool> Function();

/// No persisted unlock flag. Every process starts locked; late authentication
/// completions cannot restore an invalidated session.
class RestrictedSession extends ChangeNotifier {
  RestrictedSession({
    required this.authenticate,
    this.cancelAuthentication,
    this.mayUnlock,
    this.authenticationTimeout = const Duration(seconds: 45),
    this.sessionDuration = const Duration(hours: 4),
  });
  final DeviceAuthenticator authenticate;
  final Future<void> Function()? cancelAuthentication;
  final Duration sessionDuration, authenticationTimeout;
  final bool Function()? mayUnlock;
  bool unlocked = false, authenticating = false;
  int _generation = 0;
  bool _disposed = false;
  Timer? _expiry;

  Future<void> unlock() async {
    if (authenticating || unlocked || _disposed) return;
    final generation = ++_generation;
    authenticating = true;
    notifyListeners();
    var verified = false;
    try {
      verified = await authenticate().timeout(authenticationTimeout);
    } catch (_) {
      unawaited(cancelAuthentication?.call().catchError((Object _) {}));
    }
    if (_disposed || generation != _generation) return;
    authenticating = false;
    verified = verified && (mayUnlock?.call() ?? true);
    if (!verified) {
      unawaited(cancelAuthentication?.call().catchError((Object _) {}));
    }
    unlocked = verified;
    if (verified) _expiry = Timer(sessionDuration, lock);
    notifyListeners();
  }

  void lock() {
    if (_disposed) return;
    ++_generation;
    EditionPlaybackLock.revoke();
    _expiry?.cancel();
    unlocked = false;
    authenticating = false;
    unawaited(cancelAuthentication?.call().catchError((Object _) {}));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    EditionPlaybackLock.revoke();
    _expiry?.cancel();
    unawaited(cancelAuthentication?.call().catchError((Object _) {}));
    super.dispose();
  }
}

abstract final class WindowsDeviceAuthentication {
  static const _channel = MethodChannel('com.zanzibarr/window');
  static Future<bool> authenticate() async =>
      await _channel.invokeMethod<bool>('authenticateEdition') == true;
  static Future<void> cancel() async =>
      _channel.invokeMethod<void>('cancelEditionAuthentication');
}

class RestrictedAccessGate extends StatefulWidget {
  const RestrictedAccessGate({
    super.key,
    required this.session,
    required this.application,
  });
  final RestrictedSession session;
  final Widget Function() application;
  @override
  State<RestrictedAccessGate> createState() => _RestrictedAccessGateState();
}

class _RestrictedAccessGateState extends State<RestrictedAccessGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Windows Hello temporarily takes focus. Hidden/paused always invalidates;
    // ordinary focus loss also locks an already-unlocked application.
    if (state != AppLifecycleState.resumed &&
        (!widget.session.authenticating ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      widget.session.lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      if (widget.session.unlocked) {
        // Removing the application on lock disposes its navigators, players,
        // webviews and in-memory previews. There is no hidden retained route.
        return MaterialApp(
          key: const ValueKey(builtArtifactMarker),
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: widget.application(),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextButton.icon(
                  onPressed: widget.session.lock,
                  icon: const Icon(Icons.lock),
                  label: const Text('Lock Restricted'),
                ),
              ),
            ),
          ),
        );
      }
      return MaterialApp(
        key: const ValueKey(builtArtifactMarker),
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          appBar: AppBar(title: const Text('Zanzibarr Restricted')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 24),
                    const Text(
                      'Restricted is locked. Device authentication is '
                      'required each session. Access locks when the app loses focus '
                      'or after four hours. Configure Windows Hello in Windows account '
                      'settings if unlocking is unavailable.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Device authentication is an access control, not '
                      'proof of age. History is local to this edition; it is not '
                      'a private browsing mode.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: widget.session.authenticating
                          ? null
                          : widget.session.unlock,
                      child: Text(
                        widget.session.authenticating
                            ? 'Verifying...'
                            : 'Unlock with Windows Hello',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
