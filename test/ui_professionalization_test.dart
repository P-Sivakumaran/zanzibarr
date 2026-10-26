import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/l10n/app_localizations.dart';
import 'package:zanzibarr/main_ui_review.dart' show ReviewSurface;
import 'package:zanzibarr/settings/settings_home.dart';
import 'package:zanzibarr/ui/app_theme.dart';
import 'package:zanzibarr/ui/review_fixture.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

Widget app(
  Widget child,
  Brightness brightness, {
  double scale = 1,
  bool rtl = false,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.build(brightness, fontFamily: 'Noto Sans'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: child!,
    ),
  ),
  home: child,
);
void main() {
  testWidgets(
    'read-only native review scrolls but cannot activate service actions',
    (tester) async {
      final controller = ScrollController();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewSurface(
              child: ListView(
                controller: controller,
                children: [
                  for (var i = 0; i < 40; i++)
                    ListTile(title: Text('Action $i'), onTap: () => calls++),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Action 0'), warnIfMissed: false);
      expect(calls, 0);
      await tester.drag(find.byType(ReviewSurface), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  for (final brightness in Brightness.values) {
    test('$brightness surface, menu, error and focus contrast', () {
      final theme = AppTheme.build(brightness);
      final scheme = theme.colorScheme;
      for (final surface in [
        scheme.surface,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ]) {
        expect(contrast(scheme.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(contrast(scheme.error, scheme.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(4.5));
      expect(
        contrast(scheme.primary, scheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(scheme.outline, scheme.surfaceContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(
          theme.popupMenuTheme.textStyle!.color!,
          theme.popupMenuTheme.color!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      final focus = theme.textButtonTheme.style!.side!.resolve({
        WidgetState.focused,
      });
      expect(focus?.width, 2);
    });
  }
  testWidgets('settings can be reached using keyboard with visible focus', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SettingsHomeScreen(), Brightness.dark));
    await tester.pumpAndSettle();
    expect(find.text('Viewing'), findsOneWidget);
    expect(find.text('Playback services'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.text('Appearance settings are unavailable in this view.'),
      findsOneWidget,
    );
  });
  for (final brightness in Brightness.values) {
    for (final width in [1440.0, 390.0]) {
      for (var screen = 0; screen < 4; screen++) {
        final name =
            '${['home', 'library', 'series', 'settings'][screen]}-${brightness.name}-${width.toInt()}';
        testWidgets('production UI $name', (tester) async {
          tester.view.physicalSize = Size(width, width < 500 ? 1000 : 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final shots = Platform.environment['UI_REVIEW_SHOTS'] == '1';
          if (shots) {
            for (final (family, asset) in [
              ('Noto Sans', 'assets/fonts/subtitle.ttf'),
              ('League Mono', 'assets/fonts/LeagueMono-Thin.ttf'),
            ]) {
              await (FontLoader(
                family,
              )..addFont(rootBundle.load(asset))).load();
            }
            var dir = File(Platform.resolvedExecutable).parent;
            for (var i = 0; i < 8; i++, dir = dir.parent) {
              final font = File(
                '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
              );
              if (font.existsSync()) {
                await (FontLoader('MaterialIcons')..addFont(
                      Future.value(
                        ByteData.sublistView(font.readAsBytesSync()),
                      ),
                    ))
                    .load();
                break;
              }
            }
          }
          final images = <String, Uint8List>{};
          for (final name in [
            'quiet-coast',
            'last-orchard',
            'blue-hours',
            'place-between',
          ]) {
            images[name] = (await tester.runAsync(
              () => File('test/fixtures/figma/$name.png').readAsBytes(),
            ))!;
          }
          final fixture = ReviewFixture(images);
          await tester.pumpWidget(
            app(
              RepaintBoundary(
                key: const Key('review'),
                child: fixture.screen(screen),
              ),
              brightness,
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            for (final bytes in images.values) {
              await precacheImage(
                ResizeImage(MemoryImage(bytes), width: 500),
                tester.element(find.byKey(const Key('review'))),
              );
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen == 1) {
            expect(
              find.text('Artwork preference could not be loaded.'),
              findsNothing,
            );
            expect(
              tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
              isTrue,
            );
          }
          if (screen == 2) {
            expect(
              find.textContaining('information could not be loaded'),
              findsNothing,
            );
            expect(find.text('The lighthouse'), findsWidgets);
          }
          if (screen == 0) {
            expect(find.text('The Quiet Coast / S1 E3'), findsOneWidget);
          }
          if (shots) {
            await expectLater(
              find.byKey(const Key('review')),
              matchesGoldenFile('../dist/ui-review/gallery/$name.png'),
            );
          }
          await tester.pumpWidget(const SizedBox());
          fixture.dispose();
        });
      }
    }
  }
  testWidgets('settings 200% text and RTL remains usable', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(const SettingsHomeScreen(), Brightness.light, scale: 2, rtl: true),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Terms & privacy'), 400);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Terms & privacy'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
