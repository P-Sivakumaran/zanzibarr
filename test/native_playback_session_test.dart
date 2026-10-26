import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/native_playback_session.dart';
import 'package:zanzibarr/src/rust/api/streaming.dart';

StreamInfo info(int id) => StreamInfo(
  sessionId: BigInt.from(id),
  url: 'http://127.0.0.1/',
  castUrl: '',
  size: BigInt.one,
  filename: 'fixture',
  segmentCount: 1,
  compressed: false,
);
void main() {
  test(
    'late preparation after close is stopped and cannot be adopted',
    () async {
      final stopped = <BigInt>[];
      final session = NativePlaybackSession(
        stop: (id) async {
          stopped.add(id);
        },
      );
      final created = Completer<BigInt>();
      final pending = session.begin(() => created.future);
      await Future<void>.delayed(Duration.zero);
      await session.close();
      created.complete(BigInt.one);
      expect(await pending, null);
      expect(stopped, [BigInt.one]);
      expect(session.phase, NativePlaybackPhase.closed);
      expect(await session.begin(() async => BigInt.two), null);
    },
  );
  test('stale release never closes the next session', () async {
    final stopped = <BigInt>[];
    final session = NativePlaybackSession(
      stop: (id) async {
        stopped.add(id);
      },
    );
    await session.begin(() async => BigInt.one);
    expect(session.adopt(info(1)), true);
    await session.begin(() async => BigInt.two);
    expect(session.adopt(info(2)), true);
    await session.release(expectedId: BigInt.one);
    expect(session.info!.sessionId, BigInt.two);
    expect(stopped, [BigInt.one]);
    final first = session.close();
    await Future.wait([first, session.close()]);
    expect(stopped, [BigInt.one, BigInt.two]);
  });
  test('overlapping preparations discard the obsolete completion', () async {
    final stopped = <BigInt>[];
    final session = NativePlaybackSession(
      stop: (id) async {
        stopped.add(id);
      },
    );
    final old = Completer<BigInt>();
    final first = session.begin(() => old.future);
    await Future<void>.delayed(Duration.zero);
    await session.begin(() async => BigInt.two);
    old.complete(BigInt.one);
    expect(await first, null);
    expect(session.adopt(info(2)), true);
    expect(session.info!.sessionId, BigInt.two);
    expect(stopped, [BigInt.one]);
    await session.close();
  });
  test(
    'slow cleanup cannot let an older begin supersede a newer request',
    () async {
      final cleanup = Completer<void>();
      final stopped = <BigInt>[];
      final session = NativePlaybackSession(
        stop: (id) async {
          stopped.add(id);
          if (id == BigInt.one) await cleanup.future;
        },
      );
      await session.begin(() async => BigInt.one);
      expect(session.adopt(info(1)), true);
      var oldStarted = false;
      final old = session.begin(() async {
        oldStarted = true;
        return BigInt.from(3);
      });
      await Future<void>.delayed(Duration.zero);
      await session.begin(() async => BigInt.two);
      expect(session.adopt(info(2)), true);
      cleanup.complete();
      expect(await old, null);
      expect(oldStarted, false);
      expect(session.info!.sessionId, BigInt.two);
      await session.close();
    },
  );
  test(
    'an obsolete preparation error cannot fail the current session',
    () async {
      final session = NativePlaybackSession(stop: (_) async {});
      final previous = Completer<BigInt>();
      final old = session.begin(() => previous.future);
      await Future<void>.delayed(Duration.zero);
      await session.begin(() async => BigInt.two);
      expect(session.adopt(info(2)), true);
      previous.completeError(StateError('old preparation'));
      expect(await old, null);
      expect(session.info!.sessionId, BigInt.two);
      await session.close();
    },
  );
}
