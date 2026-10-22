import 'dart:async';
import 'package:flutter/foundation.dart';

enum RepairState { idle, starting, running, succeeded, failed, cancelled }

/// Owns one repair attempt, including a session that arrives after cancellation.
class RepairCoordinator<P, R> extends ChangeNotifier {
  RepairCoordinator({
    required this.begin,
    required this.progressFor,
    required this.resultFor,
    required this.cancelSession,
    this.pollInterval = const Duration(milliseconds: 500),
  });
  final Future<BigInt> Function(bool Function() isCurrent) begin;
  final Future<P> Function(BigInt) progressFor;
  final Future<R> Function(BigInt) resultFor;
  final Future<void> Function(BigInt) cancelSession;
  final Duration pollInterval;
  RepairState state = RepairState.idle;
  P? progress;
  String? error;
  BigInt? _session;
  Timer? _timer;
  int _generation = 0;
  bool _closed = false;
  bool get active =>
      state == RepairState.starting || state == RepairState.running;
  bool _current(int generation) => !_closed && generation == _generation;

  Future<void> _cancel(BigInt session) async {
    try {
      await cancelSession(session);
    } catch (_) {}
  }

  Future<R?> start() async {
    if (_closed || active) return null;
    final generation = ++_generation;
    state = RepairState.starting;
    error = null;
    progress = null;
    notifyListeners();
    try {
      final session = await begin(() => _current(generation));
      if (!_current(generation)) {
        await _cancel(session);
        return null;
      }
      _session = session;
      state = RepairState.running;
      notifyListeners();
      if (!_current(generation)) return null;
      var polling = false;
      _timer = Timer.periodic(pollInterval, (_) async {
        if (polling || !_current(generation)) return;
        polling = true;
        try {
          final value = await progressFor(session);
          if (_current(generation) && state == RepairState.running) {
            progress = value;
            notifyListeners();
          }
        } catch (_) {
          if (_current(generation) && state == RepairState.running) {
            _generation++;
            _timer?.cancel();
            _session = null;
            state = RepairState.failed;
            error =
                'Repair progress could not be read. The attempt was stopped.';
            notifyListeners();
            unawaited(_cancel(session));
          }
        } finally {
          polling = false;
        }
      });
      final result = await resultFor(session);
      if (!_current(generation)) return null;
      _timer?.cancel();
      _session = null;
      state = RepairState.succeeded;
      notifyListeners();
      return result;
    } catch (_) {
      if (!_current(generation)) return null;
      _timer?.cancel();
      final session = _session;
      _session = null;
      state = RepairState.failed;
      error =
          'Repair could not complete. Check provider access and recovery data.';
      notifyListeners();
      if (session != null) await _cancel(session);
      return null;
    }
  }

  void cancel() {
    if (_closed || !active) return;
    _generation++;
    _timer?.cancel();
    final session = _session;
    _session = null;
    state = RepairState.cancelled;
    notifyListeners();
    if (session != null) unawaited(_cancel(session));
  }

  @override
  void dispose() {
    if (_closed) return;
    cancel();
    _closed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
