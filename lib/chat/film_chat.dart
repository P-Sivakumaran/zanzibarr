import 'dart:async';
import 'dart:convert';

import '../integrations/codex_account.dart';
import '../integrations/integration_settings.dart';
import 'film_playlist.dart';

class FilmChatMessage {
  const FilmChatMessage(this.prompt, this.reply);
  final String prompt;
  final FilmReply reply;
}

/// Each request uses an ephemeral thread and bounded, explicit chat context.
/// No indexer credentials, library, file paths or external tools are supplied.
class FilmChat {
  FilmChat(this.account, {this.timeout = const Duration(minutes: 3)});
  final CodexAccount account;
  final Duration timeout;
  bool _busy = false;
  int _generation = 0;
  Completer<String>? _result;
  static const instructions =
      '''You are Zanzibarr's film and TV discovery assistant.
Help the user choose films, TV shows or a mix, and arrange an ordered viewing list. Reply warmly and briefly.
Recommend at most 12 real titles with a short spoiler-free description and why each fits.
Descriptions must be one sentence, at most 35 words: describe tone, filmmaking, genre or notable cast, not the sequence of events.
Do not reveal twists, endings, deaths, culprits, secret identities, relationship outcomes or later-season events. Avoid plot summaries even when recommending older titles.
Respect requests for TV shows, miniseries or films; do not turn a TV request into movie recommendations.
Set kind to "movie" for films and "tv" for TV shows and miniseries. For TV, year means the first release year.
The schema's films array holds all recommendations, including TV shows.
Use the user's language. Ask a clarifying question when needed, with an empty films list.
Respect requests to change, narrow or reorder prior recommendations. If asked for a playlist,
return the proposed full list in order. The user saves it using the app's playlist buttons.
Never claim to have saved, downloaded, searched an indexer, verified availability or started playback.
Do not invent identifiers, links, current availability or ratings. Use null for an uncertain year.
You have no need for files, commands, web, MCP, plugins or other tools. Do not call them.
Return only the JSON object described by the output schema.''';
  static const schema = <String, Object>{
    'type': 'object',
    'additionalProperties': false,
    'required': ['message', 'films'],
    'properties': {
      'message': {'type': 'string', 'maxLength': 8000},
      'films': {
        'type': 'array',
        'maxItems': 12,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['title', 'year', 'description', 'reason', 'kind'],
          'properties': {
            'title': {'type': 'string', 'maxLength': 200},
            'kind': {
              'type': 'string',
              'enum': ['movie', 'tv'],
            },
            'year': {
              'type': ['integer', 'null'],
              'minimum': 1880,
              'maximum': 2200,
            },
            'description': {'type': 'string', 'maxLength': 2000},
            'reason': {'type': 'string', 'maxLength': 1000},
          },
        },
      },
    },
  };

  static String input(String prompt, List<FilmChatMessage> history) {
    final context = <Map<String, Object>>[];
    var size = 0;
    for (final entry in history.reversed.take(10)) {
      final item = <String, Object>{
        'user': entry.prompt,
        'assistant': {
          'message': entry.reply.message,
          'films': [for (final film in entry.reply.films) film.toJson()],
        },
      };
      size += jsonEncode(item).length;
      if (size > 48000) break;
      context.insert(0, item);
    }
    return jsonEncode({'previousConversation': context, 'userMessage': prompt});
  }

  Future<FilmReply> send(String prompt, List<FilmChatMessage> history) async {
    final rpc = account.rpc;
    if (_busy) {
      throw const IntegrationException('A reply is already being prepared.');
    }
    if (!account.connected || rpc == null) {
      throw const IntegrationException(
        'Sign in with ChatGPT to start chatting.',
      );
    }
    prompt = prompt.trim();
    if (prompt.isEmpty || prompt.length > 4000) {
      throw const IntegrationException(
        'Enter a message of up to 4,000 characters.',
      );
    }
    _busy = true;
    final generation = ++_generation;
    final result = Completer<String>();
    _result = result;
    // Attach a handler immediately: disconnect/cancel may precede turn/start.
    final response = result.future.then(FilmReply.parse);
    unawaited(response.catchError((Object _) => const FilmReply('', [])));
    String? threadId;
    String? turnId;
    var finalText = '';
    final events = rpc.notifications.listen((event) {
      if (generation != _generation || result.isCompleted) return;
      if (event['method'] == 'zanzibarr/disconnected') {
        result.completeError(
          const IntegrationException(
            'Codex disconnected. Reconnect and try again.',
          ),
        );
        return;
      }
      final params = event['params'];
      if (params is! Map ||
          threadId == null ||
          params['threadId'] != threadId) {
        return;
      }
      if (event['method'] == 'turn/started' && params['turn'] is Map) {
        turnId = params['turn']['id'] as String?;
      }
      if (event['method'] == 'item/completed') {
        final item = params['item'];
        if (item is Map &&
            item['type'] == 'agentMessage' &&
            item['text'] is String) {
          finalText = item['text'] as String;
          if (finalText.length > 64000) {
            result.completeError(
              const IntegrationException(
                'The reply was too large. Ask for fewer titles.',
              ),
            );
          }
        }
      } else if (event['method'] == 'turn/completed') {
        final turn = params['turn'];
        if (turn is! Map || (turnId != null && turn['id'] != turnId)) return;
        if (turn['status'] == 'completed' && finalText.isNotEmpty) {
          result.complete(finalText);
        } else {
          result.completeError(
            const IntegrationException(
              'Codex could not finish the reply. Check your connection and subscription usage, then retry.',
            ),
          );
        }
      }
    });
    final timer = Timer(timeout, () {
      if (!result.isCompleted) {
        result.completeError(
          const IntegrationException('The reply timed out. Please try again.'),
        );
        unawaited(account.disconnect());
      }
    });
    try {
      final started = await rpc.request('thread/start', {
        'ephemeral': true,
        'approvalPolicy': 'never',
        'sandbox': 'read-only',
        'baseInstructions': instructions,
        'config': {
          'features.shell_tool': false,
          'features.apps': false,
          'features.remote_plugin': false,
          'features.multi_agent': false,
          'web_search': 'disabled',
          'project_doc_max_bytes': 0,
        },
      });
      if (generation != _generation || result.isCompleted) {
        return await response;
      }
      final thread = started['thread'];
      if (thread is! Map || thread['id'] is! String) {
        throw const FormatException('Missing thread');
      }
      threadId = thread['id'] as String;
      final startedTurn = await rpc.request('turn/start', {
        'threadId': threadId,
        'input': [
          {'type': 'text', 'text': input(prompt, history)},
        ],
        'outputSchema': schema,
        'approvalPolicy': 'never',
        'sandboxPolicy': {'type': 'readOnly', 'networkAccess': false},
      });
      if (startedTurn['turn'] is Map) {
        turnId ??= startedTurn['turn']['id'] as String?;
      }
      return await response;
    } catch (error) {
      if (generation == _generation) await account.disconnect();
      if (error is IntegrationException) rethrow;
      throw const IntegrationException(
        'The assistant returned an invalid recommendation list. Reconnect and try again.',
      );
    } finally {
      timer.cancel();
      await events.cancel();
      if (threadId != null && generation == _generation && account.connected) {
        try {
          await rpc.request('thread/unsubscribe', {'threadId': threadId});
        } catch (_) {
          await account.disconnect();
        }
      }
      if (!result.isCompleted) {
        result.completeError(const IntegrationException('Chat stopped.'));
      }
      if (generation == _generation) {
        _busy = false;
        _result = null;
      }
    }
  }

  Future<void> cancel() async {
    ++_generation;
    _busy = false;
    final result = _result;
    _result = null;
    if (result != null && !result.isCompleted) {
      result.completeError(
        const IntegrationException(
          'Reply stopped. Your message is kept for retry.',
        ),
      );
    }
    // Closing the dedicated child also cancels requests before a turn ID arrives.
    await account.disconnect();
  }
}
