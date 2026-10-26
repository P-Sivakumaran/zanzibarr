import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/settings/provider_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  var failWrite = false;
  var failCleanup = false;
  Completer<void>? writeGate;
  setUp(() {
    values.clear();
    failWrite = false;
    failCleanup = false;
    writeGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map).cast<String, dynamic>();
          final key = args['key'] as String;
          switch (call.method) {
            case 'read':
              return values[key];
            case 'write':
              if (writeGate != null) await writeGate!.future;
              if (failWrite) throw PlatformException(code: 'storage');
              values[key] = args['value'] as String;
              return null;
            case 'delete':
              if (failCleanup) throw PlatformException(code: 'storage');
              values.remove(key);
              return null;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  const old = ProviderSettings(
    host: 'old.example',
    username: 'old',
    password: 'TESTPASS123',
  );
  const next = ProviderSettings(
    host: 'new.example',
    port: 443,
    username: 'new',
    password: 'TESTPASS123',
    maxConnections: 5,
  );

  test(
    'failed record save preserves every previous credential field',
    () async {
      final store = ProviderSettingsStore();
      await store.save(old);
      failWrite = true;
      await expectLater(store.save(next), throwsA(isA<PlatformException>()));
      final loaded = await store.load();
      expect(loaded.host, old.host);
      expect(loaded.port, old.port);
      expect(loaded.username, old.username);
    },
  );
  test('reads wait for complete saves across store instances', () async {
    final first = ProviderSettingsStore(), second = ProviderSettingsStore();
    await first.save(old);
    writeGate = Completer<void>();
    final saving = first.save(next);
    final loading = second.load();
    writeGate!.complete();
    await saving;
    final loaded = await loading;
    expect(loaded.host, next.host);
    expect(loaded.port, next.port);
    expect(loaded.maxConnections, 5);
  });
  test(
    'legacy data remains readable and migrates only after successful save',
    () async {
      values.addAll({
        'provider.host': old.host,
        'provider.username': old.username,
        'provider.password': 'TESTPASS123',
      });
      final store = ProviderSettingsStore();
      expect((await store.load()).host, old.host);
      failWrite = true;
      await expectLater(store.save(next), throwsA(isA<PlatformException>()));
      expect(values['provider.host'], old.host);
      failWrite = false;
      await store.save(next);
      expect(values.containsKey('provider.password'), false);
      expect((await store.load()).host, next.host);
    },
  );
  test(
    'clear cannot resurrect old credentials when legacy deletion fails',
    () async {
      values['provider.host'] = old.host;
      failCleanup = true;
      final store = ProviderSettingsStore();
      await expectLater(store.clear(), throwsStateError);
      expect((await store.load()).isComplete, false);
      expect((await store.load()).host, isEmpty);
    },
  );
  test('corrupt new settings fail visibly without stale fallback', () async {
    values['provider.host'] = old.host;
    values[ProviderSettingsStore.recordKey] = 'broken';
    await expectLater(ProviderSettingsStore().load(), throwsStateError);
    expect(values[ProviderSettingsStore.recordKey], 'broken');
  });
}
