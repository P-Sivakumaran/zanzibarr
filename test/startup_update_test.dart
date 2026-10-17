import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/player/media_preferences.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/player/watchlist.dart';
import 'package:zanzibarr/update/update_service.dart';

class _Storage implements PlayerPreferenceStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Updates extends UpdateService {
  final result = Completer<ReleaseInfo?>();
  final checks = <bool>[];
  final installed = <ReleaseInfo>[];

  @override
  Future<ReleaseInfo?> checkForUpdate({bool ignoreSkipped = false}) {
    checks.add(ignoreSkipped);
    return result.future;
  }

  @override
  Future<void> install(
    ReleaseInfo release, {
    ValueChanged<double>? onProgress,
  }) async {
    installed.add(release);
    onProgress?.call(1);
  }
}

const _release = ReleaseInfo(
  tag: 'v9.9',
  version: '9.9.0',
  notes: 'Startup update test',
  pageUrl: 'https://github.com/P-Sivakumaran/zanzibarr/releases/tag/v9.9',
  assets: {},
);

Widget _app(_Updates updates) {
  final storage = _Storage();
  return ZanzibarrApp(
    home: HomeScreen(
      updateService: updates,
      historyStore: PlaybackHistoryStore(storage: storage),
      watchlistStore: WatchlistStore(storage: storage),
    ),
  );
}

void main() {
  testWidgets(
    'launch checks once without blocking Home or bypassing skipped versions',
    (tester) async {
      final updates = _Updates();
      await tester.pumpWidget(_app(updates));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(updates.checks, [false]);
      await tester.pump();
      expect(updates.checks, [false]);
      updates.result.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'launch offers a newer release and installs only after Update now',
    (tester) async {
      final updates = _Updates();
      await tester.pumpWidget(_app(updates));
      updates.result.complete(_release);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(updates.installed, isEmpty);
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(updates.installed, [_release]);
      expect(find.byType(AlertDialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Later dismisses launch update without installing',
    (tester) async {
      final updates = _Updates();
      await tester.pumpWidget(_app(updates));
      updates.result.complete(_release);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(updates.installed, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'offline launch remains usable without an error dialog',
    (tester) async {
      final updates = _Updates();
      await tester.pumpWidget(_app(updates));
      updates.result.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'late launch result is ignored after Home closes',
    (tester) async {
      final updates = _Updates();
      await tester.pumpWidget(_app(updates));
      await tester.pumpWidget(const SizedBox());
      updates.result.complete(_release);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
