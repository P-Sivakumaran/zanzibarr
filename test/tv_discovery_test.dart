import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/chat/ai_connections.dart';
import 'package:zanzibarr/chat/ai_http.dart';
import 'package:zanzibarr/chat/api_film_chat.dart';
import 'package:zanzibarr/chat/film_chat.dart';
import 'package:zanzibarr/chat/film_playlist.dart';
import 'film_chat_test.dart' show FakeCodex, film;
import 'integrations_test.dart' show MemoryStorage;

const show = FilmSuggestion(
  title: 'Severance',
  year: 2022,
  kind: DiscoveryKind.tv,
  description: 'Office workers separate their work and personal memories.',
  reason: 'A thoughtful mystery with an unsettling atmosphere.',
);

void main() {
  test(
    'TV suggestions route to TV search, films retain title and year search',
    () {
      expect(show.selection.kind, 'tv');
      expect(show.selection.fallbackQuery, 'Severance');
      expect(show.selection.toDto([]).kind, 'tv');
      expect(show.selection.imdbId, isNull);
      expect(film.selection.kind, 'movie');
      expect(film.selection.fallbackQuery, 'Arrival 2016');
    },
  );

  test(
    'legacy playlists default to films and mixed playlists round trip',
    () async {
      final storage = MemoryStorage();
      final legacy = film.toJson()..remove('kind');
      storage.values[FilmPlaylistStore.key] = jsonEncode({
        'version': 1,
        'playlists': [
          {
            'id': 'night',
            'name': 'Watch next',
            'films': [legacy],
          },
        ],
      });
      final store = FilmPlaylistStore(storage: storage);
      final before = await store.load();
      expect(before.single.films.single.kind, DiscoveryKind.movie);
      await store.save([
        before.single.copyWith(films: [film, show]),
      ], expected: before);
      final saved = (await store.load()).single;
      expect(saved.films.map((s) => s.kind), [
        DiscoveryKind.movie,
        DiscoveryKind.tv,
      ]);
      expect(saved.films.last.selection.kind, 'tv');
    },
  );

  test('type separates same-name titles and invalid types are rejected', () {
    final movie = show.toJson()..['kind'] = 'movie';
    final reply = FilmReply.parse(
      jsonEncode({
        'message': 'Two different titles.',
        'films': [show.toJson(), movie, show.toJson()],
      }),
    );
    expect(reply.films, hasLength(2));
    final unclassified = show.toJson()..remove('kind');
    expect(
      () => FilmReply.parse(
        jsonEncode({
          'message': 'A suggestion',
          'films': [unclassified],
        }),
      ),
      throwsFormatException,
    );
    for (final invalid in ['series', '', null, 1]) {
      expect(
        () => FilmSuggestion.fromJson(show.toJson()..['kind'] = invalid),
        throwsFormatException,
      );
    }
  });

  test(
    'Codex uses the TV-capable schema and preserves types in follow-up context',
    () async {
      final fake = FakeCodex()..suggestions = const [show];
      await fake.account.connect('codex.exe');
      try {
        final reply = await FilmChat(fake.account).send(
          'Recommend a TV mystery',
          [
            const FilmChatMessage(
              'Earlier picks',
              FilmReply('Try these.', [film, show]),
            ),
          ],
        );
        expect(reply.films.single.kind, DiscoveryKind.tv);
        final turn =
            fake.sent.firstWhere((m) => m['method'] == 'turn/start')['params']
                as Map;
        final schema = turn['outputSchema'] as Map;
        expect(
          schema['properties']['films']['items']['required'],
          contains('kind'),
        );
        expect(
          schema['properties']['films']['items']['properties']['kind']['enum'],
          ['movie', 'tv'],
        );
        final input = jsonDecode(turn['input'][0]['text']);
        expect(
          input['previousConversation'][0]['assistant']['films'][1]['kind'],
          'tv',
        );
      } finally {
        await fake.account.disconnect();
        fake.account.dispose();
      }
    },
  );

  for (final provider in [FilmAiProvider.claude, FilmAiProvider.gemini]) {
    test(
      '${provider.name} returns TV cards using the shared output contract',
      () async {
        final store = AiConnectionStore(storage: MemoryStorage());
        await store.save(
          AiConnections(
            provider: provider,
            claudeKey: 'TESTPASS123',
            geminiKey: 'TESTPASS123',
          ),
        );
        final output = jsonEncode({
          'message': 'A TV show to try.',
          'films': [show.toJson()],
        });
        final transport = AiHttp(
          clientFactory: () => MockClient((request) async {
            final body = jsonDecode(request.body);
            final schema = provider == FilmAiProvider.claude
                ? body['output_config']['format']['schema']
                : body['generationConfig']['responseFormat']['text']['schema'];
            expect(
              schema['properties']['films']['items']['properties']['kind']['enum'],
              ['movie', 'tv'],
            );
            return http.Response(
              jsonEncode(
                provider == FilmAiProvider.claude
                    ? {
                        'stop_reason': 'end_turn',
                        'content': [
                          {'type': 'text', 'text': output},
                        ],
                      }
                    : {
                        'candidates': [
                          {
                            'finishReason': 'STOP',
                            'content': {
                              'parts': [
                                {'text': output},
                              ],
                            },
                          },
                        ],
                      },
              ),
              200,
            );
          }),
        );
        final reply = await ApiFilmChat(
          store,
          http: transport,
        ).send('TV shows, please', []);
        expect(reply.films.single.selection.kind, 'tv');
        expect(reply.films.single.title, 'Severance');
      },
    );
  }
}
