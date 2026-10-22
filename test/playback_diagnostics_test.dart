import 'dart:convert';
import 'package:zanzibarr/src/rust/api/streaming.dart'
    show PlaybackTraceDto, PlaybackTraceEventDto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/playback_diagnostics.dart';
import 'package:zanzibarr/player/playback_doctor_screen.dart';

void main() {
  test('native snapshots accept only bounded known event codes', () {
    final trace = PlaybackDiagnostics()..beginAttempt();
    trace.updateNative(
      PlaybackTraceDto(
        dropped: BigInt.one,
        events: [
          PlaybackTraceEventDto(
            sequence: BigInt.one,
            elapsedMs: BigInt.from(20),
            event: 'network_failed',
          ),
          PlaybackTraceEventDto(
            sequence: BigInt.two,
            elapsedMs: BigInt.from(21),
            event: 'TESTPASS123 https://private.invalid',
          ),
        ],
      ),
    );
    expect((trace.snapshot()['nativeEvents'] as List).length, 1);
    expect(trace.report(), contains('network_failed'));
    expect(trace.report(), isNot(contains('TESTPASS123')));
    expect(trace.snapshot()['nativeDroppedEvents'], 1);
    trace.beginAttempt();
    expect(trace.snapshot()['nativeEvents'], isEmpty);
    trace.dispose();
  });

  test('startup and paused buffering are excluded from rebuffer time', () {
    var elapsed = Duration.zero;
    final trace = PlaybackDiagnostics(elapsed: () => elapsed);
    trace.beginAttempt();
    trace.playing(true);
    trace.buffering(true);
    elapsed = const Duration(seconds: 5);
    expect(trace.snapshot()['rebufferMs'], 0);
    trace.buffering(false);
    trace.decoderReady();
    elapsed = const Duration(seconds: 6);
    trace.firstFrame();
    expect(trace.firstFrameMs, 6000);
    trace.firstFrame();
    elapsed = const Duration(seconds: 7);
    trace.buffering(true);
    elapsed = const Duration(seconds: 9);
    trace.playing(false);
    expect(trace.snapshot()['rebufferMs'], 2000);
    elapsed = const Duration(seconds: 12);
    expect(trace.snapshot()['rebufferMs'], 2000);
    trace.playing(true);
    elapsed = const Duration(seconds: 13);
    trace.buffering(false);
    expect(trace.snapshot()['rebufferMs'], 3000);
    expect(trace.rebufferCount, 2);
    trace.beginAttempt();
    expect(trace.firstFrameMs, isNull);
    expect(trace.snapshot()['rebufferMs'], 0);
    trace.dispose();
  });

  test('reports omit raw failures and bound event memory', () {
    final trace = PlaybackDiagnostics()..beginAttempt();
    const failure =
        'https://user:TESTPASS123@indexer.invalid/private.nzb?apikey=TESTPASS123 connection reset';
    trace.fail(PlaybackDiagnostics.classify(failure));
    expect(trace.failure, PlaybackFailure.network);
    for (var i = 0; i < 200; i++) {
      trace.record(PlaybackEvent.seekRequested, PlaybackStage.ready);
    }
    final report = trace.report();
    expect(report, isNot(contains('TESTPASS123')));
    expect(report, isNot(contains('private.nzb')));
    expect(report, isNot(contains('https:')));
    final snapshot = trace.snapshot();
    expect((snapshot['events'] as List).length, 128);
    expect(snapshot['droppedEvents'], 74);
    ((snapshot['events'] as List).first as Map)['event'] = 'changed';
    expect(trace.report(), isNot(contains('changed')));
    trace.dispose();
    final closed = trace.report();
    trace.firstFrame();
    trace.buffering(true);
    trace.fail(PlaybackFailure.player);
    expect(trace.report(), closed);
    expect(jsonDecode(closed)['schemaVersion'], 1);
  });

  testWidgets('doctor previews a frozen report and copies only on request', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final trace = PlaybackDiagnostics(elapsed: () => elapsed)..beginAttempt();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: PlaybackDoctorScreen(diagnostics: trace)),
    );
    expect(find.text('Playback Doctor'), findsOneWidget);
    expect(copied, isNull);
    await tester.tap(find.text('Preview report'));
    await tester.pumpAndSettle();
    final preview = trace.report();
    elapsed = const Duration(seconds: 3);
    trace.decoderReady();
    await tester.pump();
    await tester.tap(find.text('Copy report'));
    await tester.pumpAndSettle();
    expect(copied, preview);
    expect(copied, isNot(trace.report()));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await tester.pumpWidget(const SizedBox());
    trace.dispose();
  });

  testWidgets('doctor remains usable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trace = PlaybackDiagnostics()..beginAttempt();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: PlaybackDoctorScreen(diagnostics: trace),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Preview report'), 250);
    await tester.tap(find.text('Preview report'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Copy report'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    trace.dispose();
  });
}
