import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/settings/legal_screen.dart';
import 'package:zanzibarr/settings/settings_home.dart';

class RetryLegalBundle extends CachingAssetBundle {
  bool fail = true;
  @override
  Future<ByteData> load(String key) {
    if (fail) throw StateError('private debug detail');
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('settings exposes offline legal pages without accepting terms', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsHomeScreen()));
    await tester.scrollUntilVisible(
      find.text('Terms & privacy'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Terms & privacy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Draft documents'), findsOneWidget);
    expect(find.textContaining('does not record acceptance'), findsOneWidget);
    await tester.ensureVisible(find.text('Privacy notice'));
    await tester.tap(find.text('Privacy notice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-10-22.draft1'), findsOneWidget);
    expect(
      find.textContaining('GitHub receives an update check'),
      findsOneWidget,
    );
    await tester.tap(find.text('Contents'));
    await tester.pumpAndSettle();
    final retention = find.text('7. Files, caches, diagnostics and retention');
    await tester.ensureVisible(retention.first);
    await tester.tap(retention.first);
    await tester.pumpAndSettle();
    expect(retention.last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terms and package licence routes work independently', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    await tester.tap(find.text('Terms of use'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not a finalized service agreement'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Package licences'));
    await tester.tap(find.text('Package licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed offline asset has a sanitized retry and can recover', (
    tester,
  ) async {
    final bundle = RetryLegalBundle();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: const MaterialApp(
          home: LegalDocumentScreen(page: LegalPage.terms),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This offline document could not be loaded.'),
      findsOneWidget,
    );
    expect(find.textContaining('private debug detail'), findsNothing);
    bundle.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Contents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final page in LegalPage.values) {
    testWidgets('${page.title} remains readable at 360px and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: LegalDocumentScreen(page: page),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -650),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
