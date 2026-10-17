import '../integrations/integration_settings.dart';
import 'ai_connections.dart';
import 'ai_http.dart';
import 'film_chat.dart';
import 'film_playlist.dart';
import 'google_oauth.dart';

class ApiFilmChat {
  ApiFilmChat(this.store, {AiHttp? http, GoogleOAuth? google})
    : http = http ?? AiHttp(),
      google = google ?? GoogleOAuth();
  final AiConnectionStore store;
  final AiHttp http;
  final GoogleOAuth google;
  bool _busy = false;
  int _generation = 0;

  // Both providers accept this structural subset. FilmReply enforces all bounds.
  static Object apiSchema(Object value) {
    if (value is List) return value.map((v) => apiSchema(v as Object)).toList();
    if (value is Map) {
      return {
        for (final entry in value.entries)
          if (![
            'maxLength',
            'minLength',
            'maxItems',
            'minimum',
            'maximum',
          ].contains(entry.key))
            entry.key as String: apiSchema(entry.value as Object),
      };
    }
    return value;
  }

  Future<FilmReply> send(String prompt, List<FilmChatMessage> history) async {
    if (_busy) {
      throw const IntegrationException('A reply is already being prepared.');
    }
    prompt = prompt.trim();
    if (prompt.isEmpty || prompt.length > 4000) {
      throw const IntegrationException(
        'Enter a message of up to 4,000 characters.',
      );
    }
    _busy = true;
    final generation = ++_generation;
    void active() {
      if (generation != _generation) {
        throw const IntegrationException(
          'Reply stopped. Your draft is kept for retry.',
        );
      }
    }

    try {
      var config = await store.load();
      active();
      final text = FilmChat.input(prompt, history);
      final schema = apiSchema(FilmChat.schema);
      Map<String, dynamic> response;
      String reply;
      if (config.provider == FilmAiProvider.claude) {
        if (config.claudeKey.isEmpty) {
          throw const IntegrationException(
            'Add your Claude API key in AI connections first.',
          );
        }
        response = await http.post(
          Uri.https('api.anthropic.com', '/v1/messages'),
          service: 'Claude',
          headers: {
            'x-api-key': config.claudeKey,
            'anthropic-version': '2023-06-01',
          },
          json: {
            'model': config.claudeModel,
            'max_tokens': 8192,
            'system': FilmChat.instructions,
            'messages': [
              {'role': 'user', 'content': text},
            ],
            'output_config': {
              'format': {'type': 'json_schema', 'schema': schema},
            },
          },
        );
        if (response['stop_reason'] != 'end_turn' ||
            response['content'] is! List) {
          throw const IntegrationException(
            'Claude could not finish the film list. Ask for fewer films or try again.',
          );
        }
        reply = (response['content'] as List)
            .whereType<Map>()
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'] as String)
            .join();
      } else if (config.provider == FilmAiProvider.gemini) {
        final headers = <String, String>{};
        if (config.geminiAuthentication == GeminiAuthentication.google) {
          config.validateGoogleClient();
          if (config.googleTokens == null) {
            throw const IntegrationException(
              'Sign in with Google in AI connections first.',
            );
          }
          if (!config.googleTokens!.fresh) {
            final tokens = await google.refresh(config);
            active();
            config = await store.updateGoogleTokens(config, tokens);
            active();
          }
          headers['authorization'] = 'Bearer ${config.googleTokens!.access}';
          headers['x-goog-user-project'] = config.googleProject;
        } else {
          if (config.geminiKey.isEmpty) {
            throw const IntegrationException(
              'Add your Gemini API key in AI connections first.',
            );
          }
          headers['x-goog-api-key'] = config.geminiKey;
        }
        response = await http.post(
          Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/${config.geminiModel}:generateContent',
          ),
          service: 'Gemini',
          headers: headers,
          json: {
            'systemInstruction': {
              'parts': [
                {'text': FilmChat.instructions},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': text},
                ],
              },
            ],
            'generationConfig': {
              'maxOutputTokens': 8192,
              'responseFormat': {
                'text': {'mimeType': 'APPLICATION_JSON', 'schema': schema},
              },
            },
          },
        );
        final candidates = response['candidates'];
        if (candidates is! List ||
            candidates.isEmpty ||
            candidates.first is! Map ||
            candidates.first['finishReason'] != 'STOP') {
          throw const IntegrationException(
            'Gemini could not finish the film list. Ask for fewer films or try again.',
          );
        }
        final parts = candidates.first['content']['parts'] as List;
        reply = parts
            .whereType<Map>()
            .where((part) => part['thought'] != true && part['text'] is String)
            .map((part) => part['text'] as String)
            .join();
      } else {
        throw const IntegrationException(
          'Choose Claude or Gemini in AI connections.',
        );
      }
      active();
      return FilmReply.parse(reply);
    } on IntegrationException {
      rethrow;
    } catch (_) {
      throw const IntegrationException(
        'The assistant returned an invalid film list. Please try again.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() async {
    ++_generation;
    http.cancel();
    google.cancel();
  }
}
