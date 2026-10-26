import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_theme.dart';
import 'ui/review_fixture.dart';

/// Explicit, offline, read-only review executable; no native engine bootstrap.
Future<void> main() async {
  if (!const bool.fromEnvironment('UI_REVIEW')) {
    throw StateError('Build this entrypoint with UI_REVIEW=true.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final directory = File(Platform.resolvedExecutable).parent;
  final images = <String, Uint8List>{};
  for (final name in [
    'quiet-coast',
    'last-orchard',
    'blue-hours',
    'place-between',
  ]) {
    images[name] = await File(
      '${directory.path}/review-art/$name.png',
    ).readAsBytes();
  }
  runApp(UiReviewApp(fixture: ReviewFixture(images)));
}

class UiReviewApp extends StatefulWidget {
  const UiReviewApp({super.key, required this.fixture});
  final ReviewFixture fixture;
  @override
  State<UiReviewApp> createState() => _UiReviewAppState();
}

class _UiReviewAppState extends State<UiReviewApp> {
  int _screen = 0;
  bool _light = false;
  @override
  void dispose() {
    widget.fixture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Zanzibarr — UI review (sample data)',
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(_light ? Brightness.light : Brightness.dark),
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('UI review • sample data • read-only'),
                  for (final (i, label) in [
                    'Home',
                    'Library',
                    'Series details',
                    'Settings',
                  ].indexed)
                    ChoiceChip(
                      label: Text(label),
                      selected: _screen == i,
                      onSelected: (_) => setState(() => _screen = i),
                    ),
                  IconButton(
                    tooltip: _light ? 'Use dark theme' : 'Use light theme',
                    onPressed: () => setState(() => _light = !_light),
                    icon: Icon(
                      _light
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReviewSurface(child: widget.fixture.screen(_screen)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Keeps real service/form actions inert while allowing the review to scroll.
class ReviewSurface extends StatelessWidget {
  ReviewSurface({super.key, required this.child});
  final Widget child;
  final _content = GlobalKey();
  void _scroll(double delta) {
    ScrollPosition? position;
    void visit(Element element) {
      if (position != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final candidate = (element.state as ScrollableState).position;
        if (candidate.hasContentDimensions && candidate.axis == Axis.vertical) {
          position = candidate;
          return;
        }
      }
      element.visitChildElements(visit);
    }

    _content.currentContext?.visitChildElements(visit);
    final target = position;
    if (target != null) {
      target.jumpTo(
        (target.pixels + delta).clamp(
          target.minScrollExtent,
          target.maxScrollExtent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerSignal: (event) {
      if (event is PointerScrollEvent) _scroll(event.scrollDelta.dy);
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => _scroll(-details.delta.dy),
      child: ExcludeFocus(
        child: IgnorePointer(key: _content, child: child),
      ),
    ),
  );
}
