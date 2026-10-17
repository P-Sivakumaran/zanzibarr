import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/integrations/codex_account.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'package:zanzibarr/integrations/mcp_transport.dart';
import 'package:zanzibarr/integrations/metadata_plugin.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/player/media_preferences.dart';

class MemoryStorage implements PlayerPreferenceStorage {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

const connection = McpConnection(
  id: 'test',
  name: 'Test',
  url: 'https://mcp.example/mcp',
  token: 'TESTPASS123',
);

http.Response rpcResponse(
  http.Request request,
  Map<String, dynamic> result, {
  Map<String, String> headers = const {},
}) {
  final message = jsonDecode(request.body) as Map;
  return http.Response(
    jsonEncode({'jsonrpc': '2.0', 'id': message['id'], 'result': result}),
    200,
    headers: {'content-type': 'application/json', ...headers},
  );
}

void main() {
  test(
    'settings are opt-in and failed saves preserve the stored configuration',
    () async {
      final storage = MemoryStorage();
      final store = IntegrationStore(storage: storage);
      final initial = await store.load();
      expect(initial.enabled, isFalse);
      expect(initial.allowPlayback, isFalse);
      await store.save(initial.copyWith(connections: [connection]));
      final before = storage.values[IntegrationStore.key];
      storage.failWrite = true;
      await expectLater(
        store.save(initial.copyWith(enabled: true)),
        throwsStateError,
      );
      expect(storage.values[IntegrationStore.key], before);
      expect((await store.load()).connections.single.token, 'TESTPASS123');
      expect((await store.load()).enabled, isFalse);
    },
  );

  test(
    'corrupt and future settings surface errors without overwriting data',
    () async {
      final storage = MemoryStorage();
      final store = IntegrationStore(storage: storage);
      for (final value in ['not json', '{"version":99}', '{"version":1}']) {
        storage.values[IntegrationStore.key] = value;
        await expectLater(store.load(), throwsA(isA<IntegrationException>()));
        expect(storage.values[IntegrationStore.key], value);
      }
    },
  );

  test(
    'remote endpoints require HTTPS and reject URL credentials and query secrets',
    () {
      for (final url in [
        'http://example.com/mcp',
        'file:///tmp/test',
        'https://user:TESTPASS123@example.com/mcp',
        'https://example.com/mcp?key=TESTPASS123',
        'https://example.com/#secret',
      ]) {
        expect(
          () => McpConnection(id: 'a', name: 'a', url: url).endpoint,
          throwsA(isA<IntegrationException>()),
        );
      }
      expect(
        McpConnection(
          id: 'a',
          name: 'a',
          url: 'http://127.0.0.1:1234/mcp',
        ).endpoint.port,
        1234,
      );
      expect(
        () => McpConnection.fromJson({
          ...connection.toJson(),
          'token': 'TESTPASS123\r\nheader: value',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'local MCP endpoint authenticates, blocks browser origins, and negotiates tools',
    () async {
      final server = LocalMcpServer(
        token: 'TESTPASS123',
        tools: () => [
          {
            'name': 'example',
            'description': 'Example',
            'inputSchema': {'type': 'object'},
          },
        ],
        call: (name, args) async => {'ok': args['value']},
      );
      await server.start();
      addTearDown(server.close);
      final client = http.Client();
      addTearDown(client.close);
      final url = 'http://127.0.0.1:${server.port}/mcp';
      final response = await client.post(
        Uri.parse(url),
        headers: {'content-type': 'application/json'},
        body: '{}',
      );
      expect(response.statusCode, 401);
      final browser = await client.post(
        Uri.parse(url),
        headers: {
          'authorization': 'Bearer TESTPASS123',
          'origin': 'https://evil.example',
          'content-type': 'application/json',
        },
        body: '{}',
      );
      expect(browser.statusCode, 403);
      final mcp = McpClient(
        McpConnection(
          id: 'local',
          name: 'local',
          url: url,
          token: 'TESTPASS123',
        ),
      );
      addTearDown(mcp.close);
      expect((await mcp.tools()).single['name'], 'example');
      final result = await mcp.call('example', {'value': 42});
      expect(jsonDecode((result['content'] as List).single['text'] as String), {
        'ok': 42,
      });
      final get = await client.get(
        Uri.parse(url),
        headers: {'authorization': 'Bearer TESTPASS123'},
      );
      expect(get.statusCode, 405);
      final path = await client.post(
        Uri.parse('$url/other'),
        headers: {'authorization': 'Bearer TESTPASS123'},
      );
      expect(path.statusCode, 404);
      final invalid = await client.post(
        Uri.parse(url),
        headers: {
          'authorization': 'Bearer TESTPASS123',
          'content-type': 'application/json',
        },
        body: '[',
      );
      expect((jsonDecode(invalid.body) as Map)['error']['code'], -32600);
    },
  );

  test(
    'permission changes take effect on calls and stale players cannot detach newer ones',
    () async {
      final runtime = IntegrationRuntime(
        store: IntegrationStore(storage: MemoryStorage()),
        library: () async => [
          {'title': 'Example'},
        ],
        search: (query) async => {'query': query},
      );
      addTearDown(runtime.shutdown);
      await runtime.load();
      final settings = runtime.settings!;
      // Do not open a listener: load a configuration into the dispatcher directly.
      runtime.settings = settings.copyWith(enabled: true);
      expect(await runtime.call('library_list', {}), [
        {'title': 'Example'},
      ]);
      await expectLater(
        runtime.call('search_releases', {'query': 'test'}),
        throwsA(isA<IntegrationException>()),
      );
      var position = 0;
      IntegrationPlayback player() => IntegrationPlayback(
        status: () => {
          'active': true,
          'durationSeconds': 100,
          'positionSeconds': position,
        },
        pause: () async {},
        resume: () async {},
        seek: (value) async => position = value.inSeconds,
      );
      final old = player();
      final current = player();
      runtime.attachPlayback(old);
      runtime.attachPlayback(current);
      runtime.detachPlayback(old);
      runtime.settings = settings.copyWith(
        enabled: true,
        allowPlayback: true,
        allowSearch: true,
      );
      expect(await runtime.call('search_releases', {'query': ' test '}), {
        'query': 'test',
      });
      await runtime.call('playback_seek', {'seconds': 50});
      expect(position, 50);
      for (final seconds in [-1, 101, double.nan]) {
        await expectLater(
          runtime.call('playback_seek', {'seconds': seconds}),
          throwsA(isA<IntegrationException>()),
        );
      }
      runtime.settings = settings.copyWith(enabled: true);
      await expectLater(
        runtime.call('playback_pause', {}),
        throwsA(isA<IntegrationException>()),
      );
      runtime.settings = settings.copyWith(enabled: false);
      await expectLater(
        runtime.call('library_list', {}),
        throwsA(isA<IntegrationException>()),
      );
    },
  );

  test(
    'HTTP client negotiates sessions and accepts JSON and SSE without leaking remote errors',
    () async {
      final methods = <String>[];
      final client = McpClient(
        connection,
        client: MockClient((request) async {
          final message = jsonDecode(request.body) as Map;
          methods.add(message['method'] as String);
          expect(request.followRedirects, isFalse);
          expect(request.headers['authorization'], 'Bearer TESTPASS123');
          if (message['method'] == 'initialize') {
            return rpcResponse(
              request,
              {'protocolVersion': mcpProtocolVersion},
              headers: {'mcp-session-id': 'session1'},
            );
          }
          expect(request.headers['mcp-session-id'], 'session1');
          if (message['method'] == 'notifications/initialized') {
            return http.Response('', 202);
          }
          if (message['method'] == 'tools/list') {
            return rpcResponse(request, {
              'tools': [
                {
                  'name': 'test',
                  'inputSchema': {'type': 'object'},
                },
              ],
            });
          }
          return http.Response(
            'id: priming\ndata:\n\nevent: message\ndata: ${jsonEncode({
              'jsonrpc': '2.0',
              'id': message['id'],
              'result': {'content': []},
            })}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      addTearDown(client.close);
      expect((await client.tools()).single['name'], 'test');
      expect(await client.call('test', {}), {'content': []});
      expect(methods, [
        'initialize',
        'notifications/initialized',
        'tools/list',
        'tools/call',
      ]);
      final failed = McpClient(
        connection,
        client: MockClient(
          (_) async => http.Response('TESTPASS123 private failure', 500),
        ),
      );
      addTearDown(failed.close);
      try {
        await failed.tools();
        fail('must fail');
      } catch (error) {
        expect(error, isA<IntegrationException>());
        expect(error.toString(), isNot(contains('TESTPASS123')));
      }
    },
  );

  test(
    'metadata plugins work without an OMDb key and preserve IMDb identity',
    () async {
      var wrongId = false;
      final client = McpClient(
        connection,
        client: MockClient((request) async {
          final message = jsonDecode(request.body) as Map;
          if (message['method'] == 'initialize') {
            return rpcResponse(request, {
              'protocolVersion': mcpProtocolVersion,
            });
          }
          if (message['method'] == 'notifications/initialized') {
            return http.Response('', 202);
          }
          final title = {
            'imdbID': wrongId ? 'tt7654321' : 'tt0133093',
            'Title': 'The Matrix',
            'Year': '1999',
            'Type': 'movie',
          };
          final data = message['params']['name'] == 'metadata_search'
              ? {
                  'Search': [title],
                  'hasMore': false,
                }
              : title;
          return rpcResponse(request, {'structuredContent': data});
        }),
      );
      final service = McpMetadataService(connection, client: client);
      addTearDown(service.close);
      expect(
        (await service.search('', 'Matrix')).titles.single.title,
        'The Matrix',
      );
      expect((await service.details('', 'tt0133093'))!.imdbId, 'tt0133093');
      wrongId = true;
      await expectLater(
        service.details('', 'tt0133093'),
        throwsA(isA<MetadataException>()),
      );
    },
  );

  test(
    'Codex startup errors identify the failing step without exposing process details',
    () async {
      final failures = <Object>[
        const ProcessException(
          'TESTPASS123',
          ['TESTPASS123'],
          'TESTPASS123',
          2,
        ),
        const FileSystemException('TESTPASS123', 'TESTPASS123'),
      ];
      for (final failure in failures) {
        final account = CodexAccount(start: (_) async => throw failure);
        try {
          await account.connect('codex.exe');
          fail('Startup should fail');
        } on IntegrationException catch (error) {
          expect(error.message, isNot(contains('TESTPASS123')));
          expect(
            error.message,
            contains(
              failure is ProcessException
                  ? 'system error 2'
                  : 'local Codex profile',
            ),
          );
        } finally {
          account.dispose();
        }
      }
    },
  );
  test(
    'Codex disconnect stops a quiet process before awaiting its decoder',
    () async {
      final stdout = StreamController<List<int>>();
      var stopped = false;
      final rpc = CodexRpc(
        CodexRpc.decodeMessages(stdout.stream),
        (message) {
          stdout.add(
            utf8.encode(
              '${jsonEncode({'id': message['id'], 'result': <String, Object>{}})}\n',
            ),
          );
        },
        () async {
          stopped = true;
          await stdout.close();
        },
      );
      await rpc.request('initialize', {});
      // Let the real decoder await another pipe chunk, as it does in the app.
      await Future<void>.delayed(Duration.zero);
      final disposal = rpc.dispose();
      try {
        await disposal.timeout(const Duration(seconds: 1));
        expect(stopped, isTrue);
      } finally {
        if (!stopped) unawaited(stdout.close());
        await disposal;
      }
    },
  );
  test(
    'Codex uses managed browser login and logout RPC without importing tokens',
    () async {
      final messages = StreamController<Map<String, dynamic>>();
      final sent = <Map<String, Object?>>[];
      late CodexRpc rpc;
      rpc = CodexRpc(messages.stream, (message) {
        sent.add(message);
        if (message['id'] == null) return;
        final method = message['method'];
        final result = method == 'account/login/start'
            ? {
                'type': 'chatgpt',
                'loginId': 'test-login',
                'authUrl': 'https://auth.openai.com/authorize?state=test',
              }
            : {'account': null};
        scheduleMicrotask(
          () => messages.add({'id': message['id'], 'result': result}),
        );
      }, () async => messages.close());
      final account = CodexAccount(start: (_) async => rpc);
      addTearDown(account.dispose);
      await account.connect('codex.exe');
      expect(sent.first['method'], 'initialize');
      expect(sent[1]['method'], 'initialized');
      expect((await account.signIn()).host, 'auth.openai.com');
      expect(sent.last['params'], {'type': 'chatgpt'});
      messages.add({
        'method': 'account/updated',
        'params': {'authMode': 'chatgpt', 'planType': 'plus'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(account.connected, isTrue);
      expect(account.plan, 'plus');
      await account.signOut();
      expect(
        sent.any((message) => message['method'] == 'account/logout'),
        isTrue,
      );
      expect(account.connected, isFalse);
      expect(sent.toString(), isNot(contains('accessToken')));
    },
  );
  test(
    'an expired remote session can reconnect on an explicit retry',
    () async {
      var initializations = 0;
      var expired = true;
      final client = McpClient(
        connection,
        client: MockClient((request) async {
          final message = jsonDecode(request.body) as Map;
          if (message['method'] == 'initialize') {
            initializations++;
            return rpcResponse(
              request,
              {'protocolVersion': mcpProtocolVersion},
              headers: {'mcp-session-id': 'session'},
            );
          }
          if (message['method'] == 'notifications/initialized') {
            return http.Response('', 202);
          }
          if (expired) {
            expired = false;
            return http.Response('', 404);
          }
          return rpcResponse(request, {'tools': <Object>[]});
        }),
      );
      addTearDown(client.close);
      await expectLater(client.tools(), throwsA(isA<IntegrationException>()));
      expect(await client.tools(), isEmpty);
      expect(initializations, 2);
    },
  );
}
