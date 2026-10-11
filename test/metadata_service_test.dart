import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/search/release_search_selection.dart';

Map<String, Object> title({String id = 'tt0133093'}) => {
  'Title': 'The Matrix',
  'Year': '1999',
  'Type': 'movie',
  'imdbID': id,
};

void main() {
  test(
    'key testing always requests OMDb and validates format before sending',
    () async {
      var requests = 0;
      final service = MetadataService(
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['apikey'], 'TESTPASS123');
          return http.Response(jsonEncode(title()), 200);
        }),
      );
      addTearDown(service.close);
      await service.details('TESTPASS123', 'tt0133093');
      await service.testApiKey(' TESTPASS123 ');
      await service.testApiKey('TESTPASS123');
      expect(requests, 3);
      await expectLater(
        service.testApiKey('https://example.test/?apikey=TESTPASS123'),
        throwsA(isA<MetadataException>()),
      );
      expect(requests, 3);
    },
  );

  test('ratings keep source labels and missing values stay absent', () {
    final media = MediaTitle.fromJson({
      ...title(),
      'Ratings': [
        {'Source': 'Internet Movie Database', 'Value': '8.7/10'},
        {'Source': 'Rotten Tomatoes', 'Value': '83%'},
        {'Source': 'Metacritic', 'Value': 'N/A'},
        {'Source': 'Unknown', 'Value': '100'},
      ],
      'Metascore': '73',
      'Plot': 'N/A',
    });
    expect(media.ratings, {
      'IMDb': '8.7/10',
      'Rotten Tomatoes': '83%',
      'Metacritic': '73/100',
    });
    expect(media.plot, isEmpty);
    expect(
      MediaTitle.fromJson({...title(), 'Ratings': 'malformed'}).ratings,
      isEmpty,
    );
  });

  test(
    'lookup is explicit, coalesced, cached and isolated on key changes',
    () async {
      var requests = 0;
      var now = DateTime(2026);
      final pending = Completer<http.Response>();
      final service = MetadataService(
        now: () => now,
        client: MockClient((request) async {
          requests++;
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'www.omdbapi.com');
          expect(request.followRedirects, isFalse);
          return requests == 1
              ? pending.future
              : http.Response(jsonEncode(title()), 200);
        }),
      );
      addTearDown(service.close);
      expect(requests, 0);
      final first = service.details('TESTPASS123', '0133093');
      final second = service.details('TESTPASS123', 'tt0133093');
      pending.complete(http.Response(jsonEncode(title()), 200));
      expect((await first)?.title, 'The Matrix');
      await second;
      await service.details('TESTPASS123', 'tt0133093');
      expect(requests, 1);
      now = now.add(const Duration(hours: 7));
      await service.details('TESTPASS123', 'tt0133093');
      expect(requests, 2);
      await service.details(' TESTPASS123 ', 'tt0133093');
      expect(requests, 3);
    },
  );

  test(
    'search pagination skips malformed rows and uses selected media kind',
    () async {
      final service = MetadataService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['s'], 'Matrix');
          expect(request.url.queryParameters['type'], 'movie');
          expect(request.url.queryParameters['page'], '2');
          return http.Response(
            jsonEncode({
              'Search': [
                title(),
                null,
                'bad',
                {...title(), 'Type': 'episode'},
              ],
              'totalResults': '30',
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final page = await service.search(
        'TESTPASS123',
        ' Matrix ',
        kind: 'movie',
        page: 2,
      );
      expect(page.titles.single.imdbId, 'tt0133093');
      expect(page.hasMore, isTrue);
    },
  );

  test('IMDb query goes directly to exact details', () async {
    final service = MetadataService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['i'], 'tt0133093');
        expect(request.url.queryParameters.containsKey('s'), isFalse);
        return http.Response(jsonEncode(title()), 200);
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.search('TESTPASS123', 'TT0133093')).titles.single.title,
      'The Matrix',
    );
  });

  test('remote errors and transport exceptions cannot expose keys', () async {
    for (final body in [
      '{"Response":"False","Error":"Invalid API key TESTPASS123"}',
      '<html>TESTPASS123</html>',
    ]) {
      final service = MetadataService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      try {
        await service.search('TESTPASS123', 'Matrix');
        fail('Expected a safe error');
      } catch (error) {
        expect(error, isA<MetadataException>());
        expect(error.toString(), isNot(contains('TESTPASS123')));
      } finally {
        service.close();
      }
    }
  });

  test(
    'not found is empty; wrong identity and oversized responses are rejected',
    () async {
      for (final body in [
        jsonEncode(title(id: 'tt0133094')),
        'x' * (1024 * 1024 + 1),
      ]) {
        final service = MetadataService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          service.details('TESTPASS123', 'tt0133093'),
          throwsA(isA<MetadataException>()),
        );
        service.close();
      }
      final service = MetadataService(
        client: MockClient(
          (_) async => http.Response(
            '{"Response":"False","Error":"Movie not found!"}',
            200,
          ),
        ),
      );
      addTearDown(service.close);
      expect((await service.search('TESTPASS123', 'Missing')).titles, isEmpty);
    },
  );

  test(
    'release hints are suggestions and fallback preserves year or episode',
    () {
      expect(releaseTitleHint('The.Matrix.1999.2160p.WEB-GRP'), 'The Matrix');
      expect(releaseTitleHint('A_Show_S02E03_1080p'), 'A Show');
      expect(
        ReleaseSearchSelection.fromMedia(
          MediaTitle.fromJson(title()),
        ).fallbackQuery,
        'The Matrix 1999',
      );
      expect(
        const ReleaseSearchSelection(
          title: 'A Show',
          kind: 'tv',
          season: 2,
          episode: 3,
        ).fallbackQuery,
        'A Show S02E03',
      );
      expect(normalizeImdbId('tt123&apikey=TESTPASS123'), isNull);
    },
  );
}
