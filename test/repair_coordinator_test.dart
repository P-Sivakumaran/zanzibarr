import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/repair_coordinator.dart';

void main() {
  test('cancel during settings loading prevents native begin', () async {
    final settings = Completer<void>();
    var nativeBegins = 0;
    final run = RepairCoordinator<int, int>(
      begin: (isCurrent) async {
        await settings.future;
        if (!isCurrent()) throw StateError('cancelled');
        nativeBegins++;
        return BigInt.one;
      },
      progressFor: (_) async => 1,
      resultFor: (_) async => 2,
      cancelSession: (_) async {},
    );
    final result = run.start();
    run.cancel();
    settings.complete();
    expect(await result, isNull);
    expect(nativeBegins, 0);
    run.dispose();
  });

  test(
    'listener cancellation on running cannot start result processing',
    () async {
      var results = 0;
      final run = RepairCoordinator<int, int>(
        begin: (_) async => BigInt.one,
        progressFor: (_) async => 1,
        resultFor: (_) async {
          results++;
          return 2;
        },
        cancelSession: (_) async {},
      );
      run.addListener(() {
        if (run.state == RepairState.running) run.cancel();
      });
      expect(await run.start(), isNull);
      expect(results, 0);
      run.dispose();
    },
  );

  test('repair startup failure is contained and permits retry', () async {
    var calls = 0;
    final run = RepairCoordinator<int, int>(
      begin: (_) async {
        if (calls++ == 0) throw StateError('TESTPASS123');
        return BigInt.one;
      },
      progressFor: (_) async => 1,
      resultFor: (_) async => 7,
      cancelSession: (_) async {},
    );
    expect(await run.start(), isNull);
    expect(run.state, RepairState.failed);
    expect(run.error, isNot(contains('TESTPASS123')));
    expect(await run.start(), 7);
    expect(run.active, isFalse);
    run.dispose();
  });

  test(
    'cancelling pending begin cancels its late session and never resumes',
    () async {
      final pending = Completer<BigInt>();
      final cancelled = <BigInt>[];
      var awaitedResults = 0;
      final run = RepairCoordinator<int, int>(
        begin: (_) => pending.future,
        progressFor: (_) async => 1,
        resultFor: (_) async {
          awaitedResults++;
          return 7;
        },
        cancelSession: (id) async => cancelled.add(id),
      );
      final result = run.start();
      run.cancel();
      pending.complete(BigInt.from(4));
      expect(await result, isNull);
      expect(cancelled, [BigInt.from(4)]);
      expect(awaitedResults, 0);
      expect(run.state, RepairState.cancelled);
      run.dispose();
    },
  );

  testWidgets(
    'polls do not overlap and a poll failure suppresses late success',
    (tester) async {
      final progress = Completer<int>();
      final result = Completer<int>();
      var polls = 0, cancels = 0;
      final run = RepairCoordinator<int, int>(
        begin: (_) async => BigInt.one,
        progressFor: (_) {
          polls++;
          return progress.future;
        },
        resultFor: (_) => result.future,
        cancelSession: (_) async {
          cancels++;
        },
        pollInterval: const Duration(milliseconds: 20),
      );
      final completion = run.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(polls, 1);
      progress.completeError(StateError('TESTPASS123'));
      await tester.pump();
      expect(run.state, RepairState.failed);
      expect(cancels, 1);
      result.complete(9);
      await tester.pump();
      expect(await completion, isNull);
      expect(run.state, RepairState.failed);
      run.dispose();
    },
  );

  test('dispose cancels a late ID and ignores late report', () async {
    final begin = Completer<BigInt>();
    var cancels = 0;
    final run = RepairCoordinator<int, int>(
      begin: (_) => begin.future,
      progressFor: (_) async => 1,
      resultFor: (_) async => 8,
      cancelSession: (_) async {
        cancels++;
      },
    );
    final done = run.start();
    run.dispose();
    begin.complete(BigInt.one);
    expect(await done, isNull);
    expect(cancels, 1);
  });
}
