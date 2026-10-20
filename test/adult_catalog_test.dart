import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/adult/adult_catalog.dart';
import 'package:zanzibarr/adult/adult_screen.dart';
import 'package:zanzibarr/player/media_preferences.dart';

class MemoryStorage implements PlayerPreferenceStorage {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('unavailable');
    values[key] = value;
  }
}

const sample = AdultTitle(
  source: AdultSource.tpdb,
  id: 'sample-id',
  title: 'Catalog fixture',
  studio: 'Example Studio',
  performers: ['Example Performer'],
);
void main() {
  test(
    'provider identities stay distinct and serialized changes survive reopen',
    () async {
      final storage = MemoryStorage();
      final store = AdultLibraryStore(storage: storage);
      await Future.wait([
        store.save(sample),
        store.save(
          const AdultTitle(
            source: AdultSource.stashdb,
            id: 'sample-id',
            title: 'Second fixture',
          ),
        ),
      ]);
      expect(await AdultLibraryStore(storage: storage).load(), hasLength(2));
      await store.save(
        const AdultTitle(
          source: AdultSource.tpdb,
          id: 'corrected',
          title: 'Correct match',
        ),
        replacing: sample.identity,
      );
      expect((await store.load()).map((t) => t.identity), [
        'tpdb:scene:corrected',
        'stashdb:scene:sample-id',
      ]);
      storage.fail = true;
      await expectLater(store.remove('tpdb:scene:corrected'), throwsStateError);
      expect(await store.load(), hasLength(2));
    },
  );
  test('unreadable library cannot be overwritten by save', () async {
    final storage = MemoryStorage()..values['adult.library.v1'] = 'invalid';
    await expectLater(
      AdultLibraryStore(storage: storage).save(sample),
      throwsFormatException,
    );
    expect(storage.values['adult.library.v1'], 'invalid');
  });
  test(
    'TPDB parses source IDs performers and validated IAFD references',
    () async {
      final catalog = AdultCatalog(
        client: MockClient((request) async {
          expect(request.url.host, 'api.theporndb.net');
          expect(request.url.path, '/movies');
          expect(request.url.queryParameters['per_page'], '20');
          expect(request.headers['Authorization'], 'Bearer TESTPASS123');
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'fixture-id',
                  'title': 'Catalog fixture',
                  'site': {'name': 'Example Studio'},
                  'performers': [
                    {'name': 'Example Performer'},
                  ],
                  'links': {
                    'IAFD': 'https://www.iafd.com/title.rme/id=fixture',
                  },
                  'poster': 'https://cdn.theporndb.net/fixture.jpg',
                },
                {'id': '../bad', 'title': 'bad'},
              ],
            }),
            200,
          );
        }),
      );
      final rows = await catalog.search(
        AdultSource.tpdb,
        'TESTPASS123',
        'fixture',
        movies: true,
      );
      expect(rows, hasLength(1));
      expect(rows.single.kind, 'movie');
      expect(rows.single.performers, ['Example Performer']);
      expect(rows.single.iafdUrl, contains('iafd.com'));
      expect(rows.single.artwork, contains('cdn.theporndb.net'));
      catalog.close();
    },
  );
  test('StashDB sends variables and unwraps performer appearances', () async {
    final catalog = AdultCatalog(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(request.url.toString(), 'https://stashdb.org/graphql');
        expect(request.headers['ApiKey'], 'TESTPASS123');
        expect(body['variables']['term'], 'Fixture " query');
        expect(body['query'], contains('performers{performer{name}}'));
        return http.Response(
          jsonEncode({
            'data': {
              'searchScene': [
                {
                  'id': 'scene-1',
                  'title': 'Scene fixture',
                  'studio': {'name': 'Studio'},
                  'performers': [
                    {
                      'performer': {'name': 'Person'},
                    },
                  ],
                },
                {'id': 'scene-2', 'title': 'Deleted fixture', 'deleted': true},
              ],
            },
          }),
          200,
        );
      }),
    );
    final rows = await catalog.search(
      AdultSource.stashdb,
      'TESTPASS123',
      'Fixture " query',
    );
    expect(rows.single.performers, ['Person']);
    catalog.close();
  });
  test(
    'rate limits prevent repeat calls and errors do not expose credentials',
    () async {
      var calls = 0;
      final catalog = AdultCatalog(
        client: MockClient((_) async {
          calls++;
          return http.Response('TESTPASS123', 429);
        }),
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          catalog.search(AdultSource.tpdb, 'TESTPASS123', 'fixture'),
          throwsA(
            isA<AdultCatalogFailure>().having(
              (e) => e.message.contains('TESTPASS123'),
              'no token',
              false,
            ),
          ),
        );
      }
      expect(calls, 1);
      catalog.close();
    },
  );
  test(
    'malformed JSON GraphQL errors oversized bodies and redirects fail safely',
    () async {
      for (final response in [
        http.Response('TESTPASS123', 200),
        http.Response('{"errors":[{"message":"TESTPASS123"}]}', 200),
        http.Response('x' * (2 * 1024 * 1024 + 1), 200),
        http.Response('', 302),
      ]) {
        final catalog = AdultCatalog(client: MockClient((_) async => response));
        await expectLater(
          catalog.search(AdultSource.tpdb, 'TESTPASS123', 'fixture'),
          throwsA(
            isA<AdultCatalogFailure>().having(
              (e) => e.toString().contains('TESTPASS123'),
              'sanitized',
              false,
            ),
          ),
        );
        catalog.close();
      }
    },
  );
  test(
    'references and artwork reject credentials redirects and unrelated hosts',
    () {
      expect(iafdReference('https://iafd.com.evil.test/'), isNull);
      expect(iafdReference('https://secret@iafd.com/'), isNull);
      expect(adultArtworkUri('http://cdn.theporndb.net/image.jpg'), isNull);
      expect(
        adultArtworkUri('https://cdn.theporndb.net/image.jpg?token=secret'),
        isNull,
      );
      expect(adultArtworkUri('https://example.test/image.jpg'), isNull);
    },
  );
  testWidgets(
    'opt-in starts without searches or artwork and saved matches reopen',
    (tester) async {
      final storage = MemoryStorage();
      final store = AdultLibraryStore(storage: storage);
      await store.save(sample);
      var calls = 0;
      final catalog = AdultCatalog(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdultLibraryScreen(store: store, catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved adult titles'), findsNothing);
      expect(calls, 0);
      await tester.tap(find.text('Enable adult catalog'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save source settings'));
      await tester.tap(find.text('Save source settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Catalog fixture'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Catalog fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Example Performer'), findsOneWidget);
      expect(calls, 0);
      expect(jsonDecode(storage.values['adult.settings.v1']!)['enabled'], true);
      catalog.close();
    },
  );
  testWidgets('load failures expose retry without editable defaults', (
    tester,
  ) async {
    final storage = MemoryStorage()..values['adult.settings.v1'] = 'broken';
    await tester.pumpWidget(
      MaterialApp(
        home: AdultLibraryScreen(store: AdultLibraryStore(storage: storage)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reload saved data'), findsOneWidget);
    expect(find.text('Save source settings'), findsNothing);
  });
}
