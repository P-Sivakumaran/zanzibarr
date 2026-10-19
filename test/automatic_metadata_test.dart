import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/metadata_visuals.dart';
import 'package:zanzibarr/metadata/title_resolver.dart';
import 'package:zanzibarr/chat/suggestion_metadata.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'metadata_library_test.dart' show MemoryStorage;

class Settings extends MetadataSettingsStore {
  Settings([this.key = 'TESTPASS123']);
  final String key;
  @override
  Future<String> load() async => key;
}

Map<String, Object?> row(
  String id, {
  String title = 'Up',
  String year = '2009',
}) => {'imdbID': id, 'Title': title, 'Year': year, 'Type': 'movie'};
http.Response response(Object data) => http.Response(jsonEncode(data), 200);
void main() {
  test(
    'automatic resolution uses type/year, coalesces requests and verifies identity',
    () async {
      var calls = 0;
      final service = MetadataService(
        client: MockClient((req) async {
          calls++;
          if (req.url.queryParameters.containsKey('s')) {
            expect(req.url.queryParameters['y'], '2009');
            expect(req.url.queryParameters['type'], 'movie');
            return response({
              'Search': [row('tt1049413')],
              'totalResults': '1',
            });
          }
          return response(row('tt1049413'));
        }),
      );
      final resolver = TitleResolver(service, Settings());
      addTearDown(service.close);
      addTearDown(resolver.close);
      final results = await Future.wait([
        resolver.resolve(title: 'Up', kind: 'movie', year: 2009),
        resolver.resolve(title: 'Up', kind: 'movie', year: 2009),
      ]);
      expect(results.map((r) => r?.imdbId), ['tt1049413', 'tt1049413']);
      expect(calls, 2);
    },
  );
  test(
    'ambiguous, partial and wrong-identity responses never get auto-attached',
    () async {
      for (final partial in [false, true]) {
        var detailCalls = 0;
        final service = MetadataService(
          client: MockClient((req) async {
            if (req.url.queryParameters.containsKey('i')) {
              detailCalls++;
              return response(row('tt9999999'));
            }
            return response({
              'Search': [row('tt1049413'), if (!partial) row('tt2345678')],
              'totalResults': partial ? '20' : '2',
            });
          }),
        );
        final resolver = TitleResolver(service, Settings());
        expect(await resolver.resolve(title: 'Up', kind: 'movie'), isNull);
        expect(detailCalls, 0);
        resolver.close();
        service.close();
      }
      final service = MetadataService(
        client: MockClient(
          (req) async => response(
            req.url.queryParameters.containsKey('s')
                ? {
                    'Search': [row('tt1049413')],
                    'totalResults': '1',
                  }
                : row('tt9999999'),
          ),
        ),
      );
      final resolver = TitleResolver(service, Settings());
      expect(
        await resolver.resolve(title: 'Up', kind: 'movie', year: 2009),
        isNull,
      );
      resolver.close();
      service.close();
    },
  );
  test(
    'missing metadata key sends nothing; release hints keep numeric titles',
    () async {
      var calls = 0;
      final service = MetadataService(
        client: MockClient((_) async {
          calls++;
          return response({});
        }),
      );
      final resolver = TitleResolver(service, Settings(''));
      expect(
        await resolver.resolve(title: 'Up', kind: 'movie', year: 2009),
        isNull,
      );
      expect(calls, 0);
      expect(releaseHint('1917.2019.1080p.BluRay.mkv').title, '1917');
      expect(releaseHint('1917.2019.1080p.BluRay.mkv').year, 2019);
      expect(releaseHint('Show.2026.S02E01.1080p.mkv').year, isNull);
      expect(releaseHint('Show.2026.S02E01.1080p.mkv').kind, 'series');
      resolver.close();
      service.close();
    },
  );
  test(
    'automatic metadata requests have at most two active operations',
    () async {
      var active = 0, peak = 0;
      final holds = <Completer<void>>[];
      final service = MetadataService(
        client: MockClient((req) async {
          active++;
          if (active > peak) peak = active;
          if (req.url.queryParameters.containsKey('s')) {
            final hold = Completer<void>();
            holds.add(hold);
            await hold.future;
          }
          active--;
          final title = req.url.queryParameters['s'] ?? 'Title';
          return response(
            req.url.queryParameters.containsKey('s')
                ? {
                    'Search': [row('tt1049413', title: title)],
                    'totalResults': '1',
                  }
                : row('tt1049413'),
          );
        }),
      );
      final resolver = TitleResolver(service, Settings());
      final jobs = [
        for (var i = 0; i < 10; i++)
          resolver.resolve(title: 'Title $i', kind: 'movie'),
      ];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(Duration.zero);
        for (final hold in [...holds]) {
          if (!hold.isCompleted) hold.complete();
        }
      }
      await Future.wait(jobs);
      expect(peak, lessThanOrEqualTo(2));
      resolver.close();
      service.close();
    },
  );
  test(
    'manual correction wins over an older automatic result and persists',
    () async {
      final old = Completer<http.Response>();
      final requested = Completer<void>();
      final service = MetadataService(
        client: MockClient((req) async {
          if (req.url.queryParameters.containsKey('s')) {
            return response({
              'Search': [row('tt1049413')],
              'totalResults': '1',
            });
          }
          if (req.url.queryParameters['i'] == 'tt1049413') {
            requested.complete();
            return old.future;
          }
          return response(row('tt2345678', title: 'Correct title'));
        }),
      );
      final storage = MemoryStorage();
      final matches = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      await matches.load();
      const pick = FilmSuggestion(
        title: 'Up',
        year: 2009,
        description: 'A film',
        reason: 'A pick',
      );
      final automatic = matches.enrich(pick);
      await requested.future;
      await matches.confirm(
        pick,
        const MediaTitle(
          imdbId: 'tt2345678',
          title: 'Correct title',
          kind: 'movie',
          year: '2009',
        ),
      );
      old.complete(response(row('tt1049413')));
      await automatic;
      expect(matches.forFilm(pick)?.imdbId, 'tt2345678');
      final restored = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      await restored.load();
      expect(restored.forFilm(pick)?.imdbId, 'tt2345678');
      matches.dispose();
      restored.dispose();
      service.close();
    },
  );
  test(
    'cached corrections refresh by their trusted ID and drive release search',
    () async {
      var searches = 0;
      final service = MetadataService(
        client: MockClient((req) async {
          if (req.url.queryParameters.containsKey('s')) searches++;
          return response({
            ...row('tt2345678', title: 'Correct title'),
            'imdbRating': '8.2',
            'imdbVotes': '123,456',
          });
        }),
      );
      final storage = MemoryStorage();
      final matches = SuggestionMetadata(
        service: service,
        settings: Settings(),
        storage: storage,
      );
      const pick = FilmSuggestion(
        title: 'Up',
        year: 2009,
        description: 'A film',
        reason: 'A pick',
      );
      storage.values['metadata.suggestion-matches.v1'] = jsonEncode({
        pick.identity: MediaTitle(
          imdbId: 'tt2345678',
          title: 'Correct title',
          year: '2009',
          kind: 'movie',
          ratings: const {'IMDb': '8.2/10'},
        ).toJson(),
      });
      await matches.load();
      await matches.enrich(pick);
      expect(searches, 0);
      expect(matches.forFilm(pick)?.ratingCounts['IMDb'], 123456);
      expect(matches.selectionFor(pick).imdbId, 'tt2345678');
      expect(matches.selectionFor(pick).title, 'Correct title');
      expect(pick.selection.imdbId, isNull);
      matches.dispose();
      service.close();
    },
  );
  test(
    'rating counts round trip by source and reject approximate or invalid values',
    () {
      final title = MediaTitle.fromJson({
        ...row('tt1049413'),
        'imdbRating': '8.2',
        'imdbVotes': '123,456',
        'Ratings': [
          {'Source': 'Rotten Tomatoes', 'Value': '95%', 'Count': '240'},
          {'Source': 'Metacritic', 'Value': '82/100', 'Count': 45},
        ],
      });
      expect(title.ratingCounts, {
        'IMDb': 123456,
        'Rotten Tomatoes': 240,
        'Metacritic': 45,
      });
      expect(
        MediaTitle.fromJson(title.toJson()).ratingCounts,
        title.ratingCounts,
      );
      final old = MediaTitle.fromJson({
        ...row('tt1049413'),
        'imdbVotes': '123,456',
        'Ratings': [
          {'Source': 'Rotten Tomatoes', 'Value': '95%'},
        ],
      });
      expect(old.ratingCounts, isEmpty);
      for (final bad in [
        '1.2M',
        '1,23',
        '-5',
        'N/A',
        0,
        -1,
        1.5,
        10000000001,
      ]) {
        expect(parseRatingCount(bad), isNull);
      }
    },
  );
  testWidgets(
    'ratings use percent positive, critic reviews and user votes with correct grammar',
    (tester) async {
      const title = MediaTitle(
        imdbId: 'tt1049413',
        title: 'Up',
        year: '2009',
        kind: 'movie',
        ratings: {
          'IMDb': '8.2/10',
          'Rotten Tomatoes': '95/100',
          'Metacritic': '82/100',
        },
        ratingCounts: {'IMDb': 123456, 'Rotten Tomatoes': 240, 'Metacritic': 1},
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RatingMeters(media: title)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotten Tomatoes: 95% positive'), findsOneWidget);
      expect(find.text('IMDb: 8.2/10'), findsOneWidget);
      expect(find.text('Metacritic: 82/100'), findsOneWidget);
      expect(find.text('Based on 123,456 votes'), findsOneWidget);
      expect(find.text('Based on 240 critic reviews'), findsOneWidget);
      expect(find.text('Based on 1 critic review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown counts stay unavailable and invalid scales have no meter',
    (tester) async {
      const title = MediaTitle(
        imdbId: 'tt1049413',
        title: 'Up',
        year: '2009',
        kind: 'movie',
        ratings: {'Rotten Tomatoes': '95/95', 'IMDb': '8.2/10'},
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RatingMeters(media: title)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotten Tomatoes: unavailable'), findsOneWidget);
      expect(find.text('Review count unavailable'), findsOneWidget);
      expect(find.text('Vote count unavailable'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );
}
