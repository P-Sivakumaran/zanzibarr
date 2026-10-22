import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/player_menu_theme.dart';

import 'l10n_test_helper.dart';
import 'subtitle_controls_overlay_test.dart' show buildOverlay;

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void expectReadable(WidgetTester tester, Finder label) {
  final context = tester.element(label);
  final foreground = DefaultTextStyle.of(context).style.color!;
  final material = tester.widget<Material>(
    find.ancestor(of: label, matching: find.byType(Material)).first,
  );
  expect(material.color, PlayerMenuTheme.surface);
  expect(contrast(foreground, material.color!), greaterThanOrEqualTo(4.5));
  expect(
    contrast(foreground, Theme.of(context).focusColor),
    greaterThanOrEqualTo(4.5),
  );
  expect(
    contrast(Theme.of(context).focusColor, material.color!),
    greaterThanOrEqualTo(3),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('subtitle font popup is readable in $brightness app theme', (
      tester,
    ) async {
      await tester.pumpWithL10n(
        Theme(
          data: ThemeData(brightness: brightness),
          child: RepaintBoundary(
            key: const ValueKey('menu-capture'),
            child: buildOverlay(),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.text_fields_rounded));
      await tester.pumpAndSettle();
      expectReadable(tester, find.text('Noto Sans'));
      final check = tester.element(find.byIcon(Icons.check));
      expect(
        contrast(IconTheme.of(check).color!, PlayerMenuTheme.surface),
        greaterThanOrEqualTo(3),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Noto Sans'), findsNothing);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        brightness,
      );
    });
  }

  testWidgets(
    'programmatic context menu scopes labels, disabled state and focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMenu<String>(
                  context: context,
                  color: PlayerMenuTheme.surface,
                  surfaceTintColor: Colors.transparent,
                  position: const RelativeRect.fromLTRB(40, 40, 40, 40),
                  items: const [
                    PlayerMenuEntry(
                      entry: PopupMenuItem(value: 'play', child: Text('Play')),
                    ),
                    PlayerMenuEntry(
                      entry: PopupMenuItem<String>(
                        enabled: false,
                        child: Text('Unavailable'),
                      ),
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expectReadable(tester, find.text('Play'));
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Unavailable')),
        ).style.color,
        PlayerMenuTheme.secondary,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsNothing);
    },
  );

  testWidgets('subtitle menu at narrow width and large text remains readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (Platform.environment['CAPTURE_PLAYER_MENU'] == '1') {
      for (final font in {
        'Noto Sans': 'subtitle',
        'Noto Serif': 'subtitle_serif',
        'Noto Sans Mono': 'subtitle_mono',
      }.entries) {
        await (FontLoader(
          font.key,
        )..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
      }
      var directory = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8; i++) {
        final icons = File(
          '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (icons.existsSync()) {
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync())),
              ))
              .load();
          break;
        }
        directory = directory.parent;
      }
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('full-menu-capture'),
        child: l10nTestApp(buildOverlay()),
      ),
    );
    await tester.tap(find.byIcon(Icons.text_fields_rounded));
    await tester.pumpAndSettle();
    expectReadable(tester, find.text('Noto Sans Mono'));
    expect(tester.takeException(), isNull);
    if (Platform.environment['CAPTURE_PLAYER_MENU'] == '1') {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('full-menu-capture')),
        );
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'dist/audit/subtitle-menu-390.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
