import 'package:zanzibarr/editions/native_gate.dart';
import 'dart:io';
import 'package:zanzibarr/editions/edition_paths.dart';
import 'package:zanzibarr/editions/native_initialization.dart';
import 'package:zanzibarr/editions/playback_lock.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/editions/clean_app.dart';
import 'package:zanzibarr/editions/content_policy.dart';
import 'package:zanzibarr/editions/edition.dart';
import 'package:zanzibarr/editions/edition_storage.dart';
import 'package:zanzibarr/editions/restricted_access.dart';

void main() {
  final now = DateTime.utc(2026, 10, 25);
  ClassificationEvidence evidence(
    String rating, {
    String id = 'tt0133093',
    bool verified = true,
    bool conflict = false,
    ClassificationSystem system = ClassificationSystem.usMpa,
    DateTime? until,
  }) => ClassificationEvidence(
    canonicalId: id,
    system: system,
    rating: rating,
    validUntil: until ?? now.add(const Duration(hours: 1)),
    authorityVerified: verified,
    conflicting: conflict,
  );
  ContentDecision decide(List<ClassificationEvidence> rows) =>
      CleanContentPolicy.evaluate('tt0133093', rows, now: now);

  test('only explicit approved classifications admit a canonical identity', () {
    for (final rating in ['G', 'PG']) {
      expect(decide([evidence(rating)]), ContentDecision.allowed);
    }
    for (final rating in ['TV-Y', 'TV-Y7', 'TV-G', 'TV-PG']) {
      expect(
        decide([evidence(rating, system: ClassificationSystem.usTv)]),
        ContentDecision.allowed,
      );
    }
    expect(decide([evidence('R')]), ContentDecision.blocked);
    expect(decide([evidence('PG'), evidence('R')]), ContentDecision.blocked);
    expect(
      decide([evidence('TV-MA', system: ClassificationSystem.usTv)]),
      ContentDecision.blocked,
    );
  });
  test('missing, spoofed, ambiguous and failed evidence never admits', () {
    expect(decide([]), ContentDecision.unclassified);
    expect(decide([evidence('U')]), ContentDecision.unclassified);
    expect(
      decide([evidence('G', verified: false)]),
      ContentDecision.verificationFailed,
    );
    expect(
      decide([evidence('G', id: 'tt0000001')]),
      ContentDecision.verificationFailed,
    );
    expect(
      decide([evidence('PG', conflict: true)]),
      ContentDecision.verificationFailed,
    );
    expect(
      decide([evidence('G', until: now)]),
      ContentDecision.verificationFailed,
    );
    expect(
      CleanContentPolicy.evaluate('not-an-id', [evidence('G')], now: now),
      ContentDecision.unclassified,
    );
    expect(
      CleanContentPolicy.evaluate(
        'tt0133093',
        [evidence('G')],
        now: now,
        verificationFailed: true,
      ),
      ContentDecision.verificationFailed,
    );
    expect(CleanContentPolicy.arbitraryMediaAllowed, isFalse);
  });
  test('file and browser roots exist and never inherit Legacy data', () async {
    final root = await Directory.systemTemp.createTemp(
      'zanzibarr-edition-test-',
    );
    try {
      final clean = await editionDirectory(root, edition: AppEdition.clean);
      final restricted = await editionDirectory(
        root,
        edition: AppEdition.restricted,
      );
      expect(await clean.exists(), isTrue);
      expect(await restricted.exists(), isTrue);
      expect(clean.path, isNot(restricted.path));
      await File('${restricted.path}/history').writeAsString('private');
      expect(await File('${clean.path}/history').exists(), isFalse);
      expect(
        (await editionDirectory(root, edition: AppEdition.legacy)).path,
        root.path,
      );
    } finally {
      final target = await root.resolveSymbolicLinks();
      final parent = await Directory.systemTemp.resolveSymbolicLinks();
      if (!target.toLowerCase().startsWith(
        '${parent.toLowerCase()}${Platform.pathSeparator}zanzibarr-edition-test-',
      )) {
        throw StateError('Test cleanup target escaped its temporary root');
      }
      await Directory(target).delete(recursive: true);
    }
  });
  test('namespace and native mismatch fail closed', () {
    expect(
      Edition.storageKey('history', edition: AppEdition.legacy),
      'history',
    );
    expect(
      Edition.storageKey('history', edition: AppEdition.clean),
      isNot(Edition.storageKey('history', edition: AppEdition.restricted)),
    );
    expect(
      () => Edition.verifyNative('engine;edition=clean;policy=clean-v1'),
      throwsStateError,
    );
    expect(
      () => Edition.verifyNative('engine;edition=legacy;policy=obsolete'),
      throwsStateError,
    );
  });
  test(
    'secure storage read, overwrite and clear cannot cross namespaces',
    () async {
      FlutterSecureStorage.setMockInitialValues({'history': 'legacy'});
      const clean = EditionSecureStorage(edition: AppEdition.clean);
      const restricted = EditionSecureStorage(edition: AppEdition.restricted);
      expect(await clean.read(key: 'history'), isNull);
      await clean.write(key: 'history', value: 'clean');
      await restricted.write(key: 'history', value: 'restricted');
      expect(await clean.readAll(), {'history': 'clean'});
      expect(await clean.containsKey(key: 'history'), isTrue);
      await clean.deleteAll();
      expect(await clean.read(key: 'history'), isNull);
      expect(await restricted.read(key: 'history'), 'restricted');
      expect(await const FlutterSecureStorage().read(key: 'history'), 'legacy');
    },
  );
  test('OS authentication missing, failed or cancelled stays locked', () async {
    for (final authenticate in <DeviceAuthenticator>[
      () async => false,
      () async => throw MissingPluginException(),
    ]) {
      final session = RestrictedSession(authenticate: authenticate);
      await session.unlock();
      expect(session.unlocked, isFalse);
      session.dispose();
    }
  });
  test(
    'late authentication cannot unlock after background or dispose',
    () async {
      final result = Completer<bool>();
      final session = RestrictedSession(authenticate: () => result.future);
      final pending = session.unlock();
      session.lock();
      result.complete(true);
      await pending;
      expect(session.unlocked, isFalse);
      session.dispose();
    },
  );
  test('authentication cannot reveal content while inactive', () async {
    final reply = Completer<bool>();
    var active = true;
    final session = RestrictedSession(
      authenticate: () => reply.future,
      mayUnlock: () => active,
    );
    final pending = session.unlock();
    active = false;
    reply.complete(true);
    await pending;
    expect(session.unlocked, isFalse);
    session.dispose();
  });
  testWidgets('timed-out authentication cancels and permits retry', (
    tester,
  ) async {
    var cancelled = 0;
    var attempt = 0;
    final session = RestrictedSession(
      authenticate: () =>
          ++attempt == 1 ? Completer<bool>().future : Future.value(true),
      authenticationTimeout: const Duration(seconds: 1),
      cancelAuthentication: () async {
        cancelled++;
      },
    );
    final pending = session.unlock();
    await tester.pump(const Duration(seconds: 2));
    await pending;
    expect(cancelled, greaterThan(0));
    expect(session.unlocked, isFalse);
    await session.unlock();
    expect(session.unlocked, isTrue);
    session.dispose();
  });
  test('native initialization survives relock and can retry failure', () async {
    final native = NativeInitialization();
    var calls = 0;
    final first = native.ensure(() async {
      calls++;
    });
    final second = native.ensure(() async {
      calls++;
    });
    await Future.wait([first, second]);
    await native.ensure(() async {
      calls++;
    });
    expect(calls, 1);
    final failing = NativeInitialization();
    await expectLater(
      failing.ensure(() async => throw StateError('failed')),
      throwsStateError,
    );
    await failing.ensure(() async {
      calls++;
    });
    expect(calls, 2);
  });
  test(
    'lock dispatches playback stop before observers or async cleanup',
    () async {
      final order = <String>[];
      EditionPlaybackLock.stop = () => order.add('stop');
      final session = RestrictedSession(
        authenticate: () async => true,
        cancelAuthentication: () async {
          order.add('cancel');
        },
      );
      await session.unlock();
      session.addListener(() => order.add('hide'));
      session.lock();
      expect(order, ['stop', 'cancel', 'hide']);
      EditionPlaybackLock.stop = null;
      session.dispose();
    },
  );
  testWidgets('verified sessions expire and remove restricted routes', (
    tester,
  ) async {
    final session = RestrictedSession(
      authenticate: () async => true,
      sessionDuration: const Duration(seconds: 2),
    );
    await tester.pumpWidget(
      RestrictedAccessGate(
        session: session,
        application: () => const MaterialApp(home: Text('Private title')),
      ),
    );
    expect(find.text('Private title'), findsNothing);
    await tester.tap(find.text('Unlock with Windows Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Private title'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Private title'), findsNothing);
    expect(find.text('Unlock with Windows Hello'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('background hides titles and stale routes cannot return', (
    tester,
  ) async {
    final session = RestrictedSession(authenticate: () async => true);
    await tester.pumpWidget(
      RestrictedAccessGate(
        session: session,
        application: () => const MaterialApp(home: Text('Private title')),
      ),
    );
    await session.unlock();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Private title'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Private title'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('restricted lock screen scrolls at narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = RestrictedSession(authenticate: () async => false);
    await tester.pumpWidget(
      RestrictedAccessGate(
        session: session,
        application: () => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unlock with Windows Hello'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unlock with Windows Hello').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('native mismatch never exposes edition content and can retry', (
    tester,
  ) async {
    var valid = false;
    await tester.pumpWidget(
      EditionNativeGate(
        initialize: () async => valid
            ? 'engine;edition=legacy;policy=clean-v1'
            : 'engine;edition=restricted;policy=clean-v1',
        child: const MaterialApp(home: Text('Approved content')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approved content'), findsNothing);
    expect(find.text('Application verification failed'), findsOneWidget);
    valid = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Approved content'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Clean cannot navigate into raw, saved or generated content', (
    tester,
  ) async {
    await tester.pumpWidget(const CleanApp());
    expect(find.text('Approved library'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.textContaining('unavailable'), findsOneWidget);
  });
}
