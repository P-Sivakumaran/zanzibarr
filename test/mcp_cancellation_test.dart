import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/integrations/integration_runtime.dart';
import 'package:zanzibarr/integrations/integration_settings.dart';
import 'package:zanzibarr/integrations/mcp_call_context.dart';
import 'package:zanzibarr/integrations/mcp_transport.dart';

class Endpoint {
  Endpoint(McpToolCall call, {Duration timeout = const Duration(seconds: 30)})
    : server = LocalMcpServer(
        token: 'TESTPASS123',
        tools: () => [],
        call: call,
        callTimeout: timeout,
      );
  final LocalMcpServer server;
  final HttpClient client = HttpClient()..maxConnectionsPerHost = 16;
  Future<void> start() => server.start();
  Future<(int, String)> send(Map<String, Object?> message) async {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}/mcp'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set('authorization', 'Bearer TESTPASS123');
    request.write(jsonEncode({'jsonrpc': '2.0', ...message}));
    final response = await request.close();
    return (response.statusCode, await utf8.decoder.bind(response).join());
  }

  Future<(int, String)> call(Object id) => send({
    'id': id,
    'method': 'tools/call',
    'params': {'name': 'playback_pause', 'arguments': <String, Object>{}},
  });
  Future<(int, String)> cancel(Object? id) => send({
    'method': 'notifications/cancelled',
    'params': {'requestId': id, 'reason': 'TESTPASS123'},
  });
  Future<void> close() async {
    await server.close();
    client.close(force: true);
  }
}

void main() {
  for (final expire in [false, true]) {
    test(
      'cancelled work retains its operation slot (expiry: $expire)',
      () async {
        final entered = List.generate(8, (_) => Completer<void>());
        final release = List.generate(8, (_) => Completer<void>());
        final finished = List.generate(8, (_) => Completer<void>());
        var count = 0;
        final endpoint = Endpoint((_, args, context) async {
          final index = count++;
          if (index < 8) {
            entered[index].complete();
            try {
              await release[index].future;
              context.check();
            } finally {
              finished[index].complete();
            }
          }
          return null;
        }, timeout: Duration(milliseconds: expire ? 50 : 30000));
        await endpoint.start();
        addTearDown(() async {
          for (final pending in release) {
            if (!pending.isCompleted) pending.complete();
          }
          await endpoint.close();
        });
        for (var i = 0; i < 8; i++) {
          final pending = endpoint.call(i);
          await entered[i].future;
          if (!expire) expect((await endpoint.cancel(i)).$1, 202);
          final response = await pending;
          if (expire) {
            expect(jsonDecode(response.$2)['result']['isError'], isTrue);
          } else {
            expect(response.$1, 202);
          }
        }
        expect((await endpoint.call(8)).$1, 503);
        expect(count, 8);
        release.first.complete();
        await finished.first.future;
        // Give the rejected underlying future's cleanup a turn to run.
        await endpoint.send({'id': 'ping', 'method': 'ping'});
        expect((await endpoint.call(9)).$1, 200);
        expect(count, 9);
      },
    );
  }

  test('monotonic deadline and finished scope reject deferred effects', () {
    final expired = McpCallContext(timeout: Duration.zero);
    expect(expired.check, throwsA(isA<IntegrationException>()));
    expect(expired.outcome, McpCallOutcome.expired);
    expired.finish();
    final finished = McpCallContext();
    finished.finish();
    expect(finished.check, throwsA(isA<IntegrationException>()));
  });

  for (final action in [
    'cancel',
    'expire',
    'revoke',
    'disable',
    'detach',
    'replace',
    'finish',
  ]) {
    for (final command in ['pause', 'resume', 'seek']) {
      test('deferred $command cannot act after $action', () async {
        final runtime = IntegrationRuntime();
        runtime.settings = IntegrationSettings(
          enabled: true,
          allowPlayback: true,
        );
        final context = McpCallContext();
        final entered = Completer<void>();
        final release = Completer<void>();
        var effects = 0;
        Future<void> deferred(void Function() authorize) async {
          entered.complete();
          await release.future;
          authorize();
          effects++;
        }

        IntegrationPlayback player() => IntegrationPlayback(
          status: () => {'active': true, 'durationSeconds': 100},
          pause: deferred,
          resume: deferred,
          seek: (_, authorize) => deferred(authorize),
        );
        final original = player();
        runtime.attachPlayback(original);
        final pending = runtime.call(
          'playback_$command',
          command == 'seek' ? {'seconds': 30} : {},
          context: context,
        );
        final rejected = expectLater(
          pending,
          throwsA(isA<IntegrationException>()),
        );
        await entered.future;
        switch (action) {
          case 'cancel':
            context.cancel();
          case 'expire':
            context.cancel(McpCallOutcome.expired);
          case 'revoke':
            runtime.settings = runtime.settings!.copyWith(allowPlayback: false);
          case 'disable':
            runtime.settings = runtime.settings!.copyWith(enabled: false);
          case 'detach':
            runtime.detachPlayback(original);
          case 'replace':
            runtime.attachPlayback(player());
          case 'finish':
            context.finish();
        }
        release.complete();
        await rejected;
        expect(effects, 0);
        context.finish();
      });
    }
  }

  test(
    'cancellation is scoped by typed active ID; duplicate cannot replace it',
    () async {
      final contexts = <Object, McpCallContext>{};
      final entered = Completer<void>();
      final release = Completer<void>();
      var count = 0;
      var effects = 0;
      final endpoint = Endpoint((_, args, context) async {
        contexts[count++] = context;
        if (count == 2) entered.complete();
        await release.future;
        context.check();
        effects++;
        return {'ok': true};
      });
      await endpoint.start();
      addTearDown(endpoint.close);
      final integer = endpoint.call(7);
      final string = endpoint.call('7');
      await entered.future;
      final duplicate = await endpoint.call(7);
      expect(jsonDecode(duplicate.$2)['error']['code'], -32600);
      final duplicatePing = await endpoint.send({'id': 7, 'method': 'ping'});
      expect(jsonDecode(duplicatePing.$2)['error']['code'], -32600);
      await endpoint.cancel('unknown');
      await endpoint.cancel(null);
      await endpoint.send({
        'method': 'notifications/cancelled',
        'params': 'invalid',
      });
      expect(contexts.values.every((c) => c.outcome == null), isTrue);
      expect((await endpoint.cancel(7)).$1, 202);
      expect((await integer).$1, 202);
      release.complete();
      expect(jsonDecode((await string).$2)['result']['isError'], isNull);
      expect(effects, 1);
      expect(
        endpoint.server.audit,
        containsAll([McpCallOutcome.cancelled, McpCallOutcome.succeeded]),
      );
      // Completed IDs are ignored and can be reused after cleanup.
      await endpoint.cancel('7');
      expect((await endpoint.call(7)).$1, 200);
    },
  );

  test(
    'endpoint deadline returns safely and late callback has zero effects',
    () async {
      final entered = Completer<McpCallContext>();
      final release = Completer<void>();
      final finished = Completer<void>();
      var effects = 0;
      final endpoint = Endpoint((_, args, context) async {
        entered.complete(context);
        try {
          await release.future;
          context.check();
          effects++;
          return null;
        } finally {
          finished.complete();
        }
      }, timeout: const Duration(milliseconds: 50));
      await endpoint.start();
      addTearDown(endpoint.close);
      final pending = endpoint.call(1);
      final context = await entered.future;
      await context.cancelled;
      expect(jsonDecode((await pending).$2)['result']['isError'], isTrue);
      release.complete();
      await finished.future;
      expect(effects, 0);
      expect(endpoint.server.audit, [McpCallOutcome.expired]);
    },
  );

  test(
    'shutdown cancels waiting scope before late callback is released',
    () async {
      final entered = Completer<McpCallContext>();
      final release = Completer<void>();
      final finished = Completer<void>();
      var effects = 0;
      final endpoint = Endpoint((_, args, context) async {
        entered.complete(context);
        try {
          await release.future;
          context.check();
          effects++;
          return null;
        } finally {
          finished.complete();
        }
      });
      await endpoint.start();
      addTearDown(endpoint.close);
      // Force-close can terminate HTTP before any response is sent.
      final pending = endpoint
          .call(1)
          .then<Object?>((v) => v, onError: (Object _) => null);
      final context = await entered.future;
      await endpoint.server.close();
      await context.cancelled;
      expect(context.outcome, McpCallOutcome.closed);
      release.complete();
      await finished.future;
      await pending;
      expect(effects, 0);
    },
  );

  test(
    'eight active HTTP requests remains the limit and audit is bounded',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var count = 0;
      final endpoint = Endpoint((_, args, context) async {
        count++;
        if (count == 8) entered.complete();
        if (count <= 8) await release.future;
        context.check();
        return 'TESTPASS123';
      });
      await endpoint.start();
      addTearDown(endpoint.close);
      final pending = List.generate(8, endpoint.call);
      await entered.future;
      expect((await endpoint.call(9)).$1, 503);
      release.complete();
      await Future.wait(pending);
      for (var i = 0; i < 130; i++) {
        await endpoint.call(i);
      }
      expect(endpoint.server.audit.length, 128);
      expect(
        endpoint.server.audit.every((v) => v == McpCallOutcome.succeeded),
        isTrue,
      );
      expect(endpoint.server.audit.toString(), isNot(contains('TESTPASS123')));
    },
  );

  test('revoked read permission suppresses deferred library result', () async {
    final release = Completer<Object?>();
    final runtime = IntegrationRuntime(library: () => release.future);
    runtime.settings = IntegrationSettings(enabled: true);
    final pending = expectLater(
      runtime.call('library_list', {}),
      throwsA(isA<IntegrationException>()),
    );
    runtime.settings = runtime.settings!.copyWith(enabled: false);
    release.complete(['private title']);
    await pending;
  });
}
