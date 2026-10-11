import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/l10n/app_localizations.dart';
import 'package:zanzibarr/metadata/metadata_screen.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';

class _Store extends MetadataSettingsStore {
  _Store(this.key);
  String key;
  bool fail = false;
  @override
  Future<String> load() async => key;
  @override
  Future<void> save(String key) async {
    if (fail) throw StateError('secure storage unavailable');
    this.key = key;
  }
}

class _Service extends MetadataService {
  int requests = 0;
  String? testedKey;
  String? testError;
  @override
  Future<void> testApiKey(String apiKey) async {
    requests++;
    testedKey = apiKey;
    if (testError != null) throw MetadataException(testError!);
  }

  static const media = MediaTitle(
    imdbId: 'tt0133093',
    title: 'The Matrix',
    year: '1999',
    kind: 'movie',
    plot: 'A computer programmer discovers a hidden reality.',
    ratings: {'IMDb': '8.7/10', 'Rotten Tomatoes': '83%'},
  );
  @override
  Future<MetadataPage> search(
    String apiKey,
    String query, {
    String? kind,
    int page = 1,
  }) async {
    requests++;
    return const MetadataPage([media]);
  }

  @override
  Future<MediaTitle?> details(String apiKey, String id) async {
    requests++;
    return media;
  }
}

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  testWidgets(
    'API test validates the draft without saving and resets after edits',
    (tester) async {
      final service = _Service();
      addTearDown(service.close);
      final store = _Store('');
      await tester.pumpWidget(
        _app(MetadataScreen(service: service, store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.key_rounded));
      await tester.pumpAndSettle();
      final keyField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.tap(find.text('Test API key'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an API key to test.'), findsOneWidget);
      expect(service.requests, 0);
      await tester.enterText(
        keyField,
        'https://www.omdbapi.com/?apikey=TESTPASS123',
      );
      await tester.tap(find.text('Test API key'));
      await tester.pumpAndSettle();
      expect(service.requests, 0);
      await tester.enterText(keyField, ' TESTPASS123 ');
      await tester.tap(find.text('Test API key'));
      await tester.pumpAndSettle();
      expect(service.testedKey, 'TESTPASS123');
      expect(find.textContaining('This API key works.'), findsOneWidget);
      expect(store.key, isEmpty);
      await tester.enterText(keyField, 'TESTPASS123');
      await tester.pump();
      expect(find.textContaining('This API key works.'), findsNothing);
      service.testError = 'key';
      await tester.tap(find.text('Test API key'));
      await tester.pumpAndSettle();
      expect(
        find.text('OMDb rejected the API key. Check OMDb settings.'),
        findsOneWidget,
      );
      expect(store.key, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lookup requires an explicit action and shows source-labelled ratings',
    (tester) async {
      final service = _Service();
      addTearDown(service.close);
      await tester.pumpWidget(
        _app(
          MetadataScreen(
            service: service,
            store: _Store('TESTPASS123'),
            initialQuery: 'Matrix',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.requests, 0);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(service.requests, 1);
      await tester.tap(find.text('The Matrix'));
      await tester.pumpAndSettle();
      expect(service.requests, 2);
      expect(find.text('IMDb: 8.7/10'), findsOneWidget);
      expect(find.text('Rotten Tomatoes: 83%'), findsOneWidget);
      await tester.tap(find.text('Find releases'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller!.text, 'The Matrix');
      expect(fields[1].controller!.text, 'tt0133093');
      expect(fields[2].controller!.text, '1999');
    },
  );

  testWidgets(
    'manual search remains available without a key at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Service();
      addTearDown(service.close);
      await tester.pumpWidget(
        _app(MetadataScreen(service: service, store: _Store('')), scale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final manual = find.widgetWithText(TextButton, 'Precise release search');
      await tester.ensureVisible(manual);
      await tester.pumpAndSettle();
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(service.requests, 0);
    },
  );

  testWidgets(
    'failed key saves retain the draft and cancel asks before discarding',
    (tester) async {
      final service = _Service();
      addTearDown(service.close);
      final store = _Store('')..fail = true;
      await tester.pumpWidget(
        _app(MetadataScreen(service: service, store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.key_rounded));
      await tester.pumpAndSettle();
      final keyField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(keyField, 'TESTPASS123');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(keyField).controller!.text,
        'TESTPASS123',
      );
      expect(tester.widget<TextField>(keyField).obscureText, isTrue);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes'), findsOneWidget);
      expect(store.key, isEmpty);
    },
  );
}
