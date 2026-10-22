import 'dart:convert';
import '../src/rust/api/streaming.dart' show PlaybackTraceDto;
import 'package:flutter/foundation.dart';

enum PlaybackStage {
  preparing,
  selectingMedia,
  connecting,
  openingDecoder,
  ready,
  buffering,
  paused,
  repairing,
  failed,
  stopped,
}

enum PlaybackEvent {
  attemptStarted,
  selectingMedia,
  providerConnecting,
  streamPrepared,
  archivePrepared,
  localFileOpening,
  decoderReady,
  firstFrame,
  bufferingStarted,
  bufferingEnded,
  paused,
  playing,
  seekRequested,
  seekCommandCompleted,
  seekFailed,
  startupTimeout,
  repairStarted,
  repairCompleted,
  repairFailed,
  repairCancelled,
  failed,
  stopped,
}

enum PlaybackFailure {
  configuration,
  network,
  archive,
  decoder,
  player,
  unknown,
}

/// Only typed events and monotonic durations enter this report. Never attach
/// exception strings, media names, URLs, paths, track labels or credentials.
class PlaybackDiagnostics extends ChangeNotifier {
  PlaybackDiagnostics({Duration Function()? elapsed}) {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? (() => watch.elapsed);
  }
  late final Duration Function() _elapsed;
  final _events = <Map<String, Object>>[];
  List<Map<String, Object>> _native = [];
  int _nativeDropped = 0;
  static const _nativeKinds = {
    'started',
    'selection_failed',
    'archive_preparing',
    'stream_preparing',
    'preparation_failed',
    'stream_ready',
    'range_requested',
    'range_completed',
    'range_failed',
    'segment_requested',
    'segment_decoded',
    'segment_failed',
    'network_failed',
    'decode_failed',
    'connection_retry',
    'cancelled',
    'finished',
  };
  void updateNative(PlaybackTraceDto trace) {
    if (_closed || trace.events.length > 128 || trace.dropped.bitLength > 53) {
      return;
    }
    _native = [
      for (final event in trace.events)
        if (_nativeKinds.contains(event.event) &&
            event.sequence.bitLength <= 53 &&
            event.elapsedMs.bitLength <= 53)
          {
            'sequence': event.sequence.toInt(),
            'elapsedMs': event.elapsedMs.toInt(),
            'event': event.event,
          },
    ];
    _nativeDropped = trace.dropped.toInt();
    notifyListeners();
  }

  PlaybackStage stage = PlaybackStage.preparing;
  PlaybackFailure? failure;
  int attempt = 0;
  int? firstFrameMs;
  int? decoderReadyMs;
  int rebufferCount = 0;
  Duration _attemptAt = Duration.zero;
  Duration _rebufferTotal = Duration.zero;
  Duration? _rebufferAt;
  bool _buffering = false;
  bool _playing = false;
  bool _closed = false;
  int droppedEvents = 0;

  void beginAttempt() {
    if (_closed) return;
    attempt++;
    _attemptAt = _elapsed();
    _native = [];
    _nativeDropped = 0;
    firstFrameMs = null;
    decoderReadyMs = null;
    rebufferCount = 0;
    _rebufferTotal = Duration.zero;
    _rebufferAt = null;
    _buffering = false;
    _playing = false;
    failure = null;
    record(PlaybackEvent.attemptStarted, PlaybackStage.preparing);
  }

  void record(PlaybackEvent event, PlaybackStage next) {
    if (_closed) return;
    stage = next;
    if (_events.length == 128) {
      _events.removeAt(0);
      droppedEvents++;
    }
    _events.add({
      'elapsedMs': _elapsed().inMilliseconds,
      'attempt': attempt,
      'event': event.name,
      'stage': next.name,
    });
    notifyListeners();
  }

  void decoderReady() {
    if (decoderReadyMs != null || _closed) return;
    decoderReadyMs = (_elapsed() - _attemptAt).inMilliseconds;
    record(PlaybackEvent.decoderReady, PlaybackStage.ready);
  }

  void firstFrame() {
    if (firstFrameMs != null || _closed) return;
    firstFrameMs = (_elapsed() - _attemptAt).inMilliseconds;
    _updateRebuffer();
    record(PlaybackEvent.firstFrame, _currentStage);
  }

  PlaybackStage get _currentStage => _buffering
      ? PlaybackStage.buffering
      : _playing
      ? PlaybackStage.ready
      : PlaybackStage.paused;

  void playing(bool value) {
    if (_closed || value == _playing) return;
    _playing = value;
    _updateRebuffer();
    record(
      value ? PlaybackEvent.playing : PlaybackEvent.paused,
      decoderReadyMs == null ? stage : _currentStage,
    );
  }

  void buffering(bool value) {
    if (_closed || value == _buffering) return;
    _buffering = value;
    _updateRebuffer();
    record(
      value ? PlaybackEvent.bufferingStarted : PlaybackEvent.bufferingEnded,
      decoderReadyMs == null ? stage : _currentStage,
    );
  }

  void _updateRebuffer() {
    final active = firstFrameMs != null && _playing && _buffering;
    if (active && _rebufferAt == null) {
      _rebufferAt = _elapsed();
      rebufferCount++;
    } else if (!active && _rebufferAt != null) {
      _rebufferTotal += _elapsed() - _rebufferAt!;
      _rebufferAt = null;
    }
  }

  void fail(PlaybackFailure category) {
    if (_closed) return;
    _playing = false;
    _updateRebuffer();
    failure = category;
    record(PlaybackEvent.failed, PlaybackStage.failed);
  }

  /// A coarse classification of a reported error, not a proven root cause.
  static PlaybackFailure classify(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('authentication') ||
        text.contains('password') ||
        text.contains('settings missing')) {
      return PlaybackFailure.configuration;
    }
    if (text.contains('rar') ||
        text.contains('archive') ||
        text.contains('7z') ||
        text.contains('par2')) {
      return PlaybackFailure.archive;
    }
    if (text.contains('socket') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('nntp') ||
        text.contains('http')) {
      return PlaybackFailure.network;
    }
    if (text.contains('decoder') ||
        text.contains('codec') ||
        text.contains('demux')) {
      return PlaybackFailure.decoder;
    }
    return PlaybackFailure.unknown;
  }

  Map<String, Object?> snapshot() => {
    'schemaVersion': 1,
    'scope': 'player-and-native-observations',
    'nativeEvents': [
      for (final event in _native) Map<String, Object>.of(event),
    ],
    'nativeDroppedEvents': _nativeDropped,
    'attempt': attempt,
    'stage': stage.name,
    'reportedFailureCategory': failure?.name,
    'decoderReadyMs': decoderReadyMs,
    'firstFrameMs': firstFrameMs,
    'rebufferCount': rebufferCount,
    'rebufferMs':
        (_rebufferTotal +
                (_rebufferAt == null
                    ? Duration.zero
                    : _elapsed() - _rebufferAt!))
            .inMilliseconds,
    'droppedEvents': droppedEvents,
    'events': [for (final event in _events) Map<String, Object>.of(event)],
  };

  String report() => const JsonEncoder.withIndent('  ').convert(snapshot());

  @override
  void dispose() {
    if (_closed) return;
    _playing = false;
    _updateRebuffer();
    record(PlaybackEvent.stopped, PlaybackStage.stopped);
    _closed = true;
    super.dispose();
  }
}
