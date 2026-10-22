import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/src/rust/api/repair.dart';
import 'package:zanzibarr/src/rust/api/simple.dart';
import 'package:zanzibarr/src/rust/api/streaming.dart';
import 'package:zanzibarr/src/rust/frb_generated.dart';

import 'l10n_test_helper.dart';

/// Faz 0 köprü kanıtı: Rust dylib'i host'ta derlenmiş olmalı
/// (`cargo build --manifest-path rust/Cargo.toml`).
String _dylibPath() {
  final name = switch (Platform.operatingSystem) {
    'macos' => 'librust_lib_zanzibarr.dylib',
    'linux' => 'librust_lib_zanzibarr.so',
    'windows' => 'rust_lib_zanzibarr.dll',
    _ => throw UnsupportedError('Desteklenmeyen test platformu'),
  };
  return 'rust/target/debug/$name';
}

void main() {
  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_dylibPath()));
  });

  test('Dart, Rust fonksiyonunu çağırabiliyor (köprü ayakta)', () {
    expect(
      greet(name: 'Zanzibarr'),
      'Merhaba Zanzibarr, Rust çekirdeği ayakta! 🦀',
    );
    expect(engineInfo(), startsWith('rust_lib_zanzibarr v'));
  });

  test(
    'provider connection check crosses the bridge with safe errors',
    () async {
      await expectLater(
        checkProvider(
          config: const ProviderConfigDto(
            host: 'invalid host',
            port: 563,
            username: 'test',
            password: 'TESTPASS123',
            maxConnections: 1,
          ),
        ),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('provider connection failed') &&
                !error.toString().contains('TESTPASS123'),
          ),
        ),
      );
    },
  );

  test(
    'repair bridge passes the selected entry to Rust before networking',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'zanzibarr-repair-bridge-',
      );
      try {
        final nzb = File('${dir.path}/episodes.nzb');
        await nzb.writeAsString('''
<nzb><file subject='"episode.mkv" yEnc (1/1)'><segments>
<segment bytes="100" number="1">test@example.invalid</segment>
</segments></file></nzb>
''');
        final session = await beginRepair(
          config: const ProviderConfigDto(
            host: 'unused.invalid',
            port: 563,
            username: 'test',
            password: 'TESTPASS123',
            maxConnections: 1,
          ),
          nzbPath: nzb.path,
          entryKey: 'direct:missing.mkv',
        );
        await expectLater(
          awaitRepair(sessionId: session),
          throwsA(
            predicate(
              (Object error) =>
                  error.toString().contains('selected entry is no longer'),
            ),
          ),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'native diagnostic snapshots cross the bridge without source data',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'zanzibarr-trace-bridge-',
      );
      try {
        final file = File('${dir.path}/private-title-TESTPASS123.nzb');
        await file.writeAsString('<nzb/>');
        final session = await beginStream(
          config: const ProviderConfigDto(
            host: 'unused.invalid',
            port: 563,
            username: 'test',
            password: 'TESTPASS123',
            maxConnections: 1,
          ),
          nzbPath: file.path,
        );
        await expectLater(awaitStream(sessionId: session), throwsA(anything));
        final snapshot = await playbackTrace(sessionId: session);
        expect(snapshot, isNotNull);
        expect(
          snapshot!.events.map((event) => event.event),
          contains('selection_failed'),
        );
        expect(snapshot.events.length, lessThanOrEqualTo(128));
        expect(
          snapshot.events.map((event) => event.event).join(','),
          isNot(contains('TESTPASS123')),
        );
        expect(await playbackTrace(sessionId: BigInt.zero), isNull);
        await stopStream(sessionId: session);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets('Ana ekran medya açma akışını sunuyor', (tester) async {
    await tester.pumpWidget(
      ZanzibarrApp(uiPreferences: turkishUiPreferences()),
    );
    expect(find.text('NZB seç ve oynat'), findsOneWidget);
  });
}
