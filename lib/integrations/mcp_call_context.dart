import 'dart:async';

import 'integration_settings.dart';

enum McpCallOutcome { succeeded, failed, cancelled, expired, closed }

/// Cooperative lifetime, not a guarantee that an issued native command stops.
class McpCallContext {
  McpCallContext({this.timeout = const Duration(seconds: 30)}) {
    _timer = Timer(timeout, () => cancel(McpCallOutcome.expired));
  }

  final Duration timeout;
  final Stopwatch _clock = Stopwatch()..start();
  final Completer<void> _cancelled = Completer<void>();
  late final Timer _timer;
  bool _finished = false;
  McpCallOutcome? _outcome;
  Future<void> get cancelled => _cancelled.future;
  McpCallOutcome? get outcome => _outcome;

  void check() {
    // Check the monotonic clock too: timer delivery can be delayed.
    if (!_finished && _outcome == null && _clock.elapsed >= timeout) {
      cancel(McpCallOutcome.expired);
    }
    if (_finished || _outcome != null) {
      throw const IntegrationException('MCP call is no longer active.');
    }
  }

  void cancel([McpCallOutcome reason = McpCallOutcome.cancelled]) {
    if (_finished || _outcome != null) return;
    _outcome = reason;
    _timer.cancel();
    _cancelled.complete();
  }

  void finish() {
    _finished = true;
    _timer.cancel();
    _clock.stop();
  }
}
