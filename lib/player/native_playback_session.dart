import 'dart:async';
import '../src/rust/api/streaming.dart' show StreamInfo;

enum NativePlaybackPhase { idle, preparing, ready, closed }

/// Owns one native session across asynchronous preparation and view teardown.
/// Late completions may clean up their own ID, never adopt or stop a successor.
class NativePlaybackSession {
  NativePlaybackSession({required this.stop});
  final Future<void> Function(BigInt id) stop;
  NativePlaybackPhase _phase = NativePlaybackPhase.idle;
  NativePlaybackPhase get phase => _phase;
  int _generation = 0;
  BigInt? _pending;
  StreamInfo? _info;
  BigInt? get pendingId => _pending;
  StreamInfo? get info => _info;
  BigInt? get id => _info?.sessionId ?? _pending;
  Future<void>? _closing;

  Future<BigInt?> begin(Future<BigInt> Function() prepare) async {
    if (_phase == NativePlaybackPhase.closed) return null;
    // Reserve request ordering before asynchronous cleanup. An older request
    // must not regain authority when a slow stop completes after a newer begin.
    final generation = ++_generation;
    final previous = id;
    _pending = null;
    _info = null;
    _phase = NativePlaybackPhase.preparing;
    if (previous != null) await _stop(previous);
    if (generation != _generation || _phase == NativePlaybackPhase.closed) {
      return null;
    }
    BigInt created;
    try {
      created = await prepare();
    } catch (_) {
      if (generation != _generation || _phase == NativePlaybackPhase.closed) {
        return null;
      }
      _phase = NativePlaybackPhase.idle;
      rethrow;
    }
    if (generation != _generation || _phase == NativePlaybackPhase.closed) {
      await _stop(created);
      return null;
    }
    _pending = created;
    return created;
  }

  bool adopt(StreamInfo info) {
    if (_phase == NativePlaybackPhase.ready &&
        _info?.sessionId == info.sessionId) {
      return true;
    }
    if (_phase != NativePlaybackPhase.preparing || _pending != info.sessionId) {
      unawaited(_stop(info.sessionId));
      return false;
    }
    _pending = null;
    _info = info;
    _phase = NativePlaybackPhase.ready;
    return true;
  }

  Future<void> release({BigInt? expectedId}) async {
    if (expectedId != null && id != expectedId) return;
    ++_generation;
    final previous = id;
    _pending = null;
    _info = null;
    if (_phase != NativePlaybackPhase.closed) _phase = NativePlaybackPhase.idle;
    if (previous != null) await _stop(previous);
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _phase = NativePlaybackPhase.closed;
    return _closing = release();
  }

  Future<void> _stop(BigInt id) async {
    if (id == BigInt.zero) return;
    try {
      await stop(id);
    } catch (_) {
      /* Cleanup cannot restore a session. */
    }
  }
}
