import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'package:zanzibarr/integrations/integrations_screen.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/metadata/metadata_screen.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';

import 'integrations_test.dart' show MemoryStorage;

class _NoKeyStore extends MetadataSettingsStore {
  int loads = 0;
  @override
  Future<String> load() async {
    loads++;
    throw StateError('must not read OMDb credentials');
  }
}

class _Plugin extends MetadataService {
  int searches = 0;
  @override
  Future<MetadataPage> search(
    String apiKey,
    String query, {
    String? kind,
    int page = 1,
  }) async {
    searches++;
    return const MetadataPage([
      MediaTitle(
        imdbId: 'tt0133093',
        title: 'The Matrix',
        year: '1999',
        kind: 'movie',
      ),
    ]);
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets(
    'integration controls reflow at large text and persist search permission',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final runtime = IntegrationRuntime(
        store: IntegrationStore(storage: storage),
      );
      addTearDown(runtime.shutdown);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: IntegrationsScreen(
              runtime: runtime,
              discoverCodex: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signIn = find.byKey(const Key('integration-sign-in'));
      expect(signIn.hitTestable(), findsOneWidget);
      expect(tester.widget<FilledButton>(signIn).onPressed, isNotNull);
      expect(find.text('Sign in with ChatGPT').hitTestable(), findsOneWidget);
      expect(runtime.settings!.enabled, isFalse);
      await tester.scrollUntilVisible(
        find.text('Allow indexer searches'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Allow indexer searches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow indexer searches'));
      await tester.pumpAndSettle();
      expect(
        (await IntegrationStore(storage: storage).load()).allowSearch,
        isTrue,
      );
      expect(runtime.running, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('connection drafts survive failed secure-storage saves', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final runtime = IntegrationRuntime(
      store: IntegrationStore(storage: storage),
    );
    addTearDown(runtime.shutdown);
    await tester.pumpWidget(
      MaterialApp(
        home: IntegrationsScreen(
          runtime: runtime,
          discoverCodex: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final add = find.text('Add MCP connection or metadata plugin');
    await tester.scrollUntilVisible(
      add,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'My provider');
    await tester.enterText(
      field('MCP endpoint URL'),
      'https://provider.example/mcp',
    );
    storage.failWrite = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('My provider'), findsOneWidget);
    expect(find.textContaining('your draft is retained'), findsOneWidget);
    expect(runtime.settings!.connections, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'metadata plugin lookup bypasses OMDb credentials and labels its source',
    (tester) async {
      final service = _Plugin();
      addTearDown(service.close);
      final store = _NoKeyStore();
      await tester.pumpWidget(
        ZanzibarrApp(
          home: MetadataScreen(
            service: service,
            store: store,
            providerName: 'Example provider',
            requiresApiKey: false,
            initialQuery: 'Matrix',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.loads, 0);
      expect(
        find.textContaining(
          'Queries and title IDs are sent to Example provider',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(service.searches, 1);
      expect(find.text('The Matrix'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
