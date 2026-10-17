import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'integration_settings.dart';

const mcpProtocolVersion = '2025-11-25';
const _supportedVersions = ['2025-11-25', '2025-06-18', '2025-03-26'];
const _maxBody = 2 * 1024 * 1024;

Future<List<int>> _bounded(
  Stream<List<int>> stream,
  int limit, {
  Duration timeout = const Duration(seconds: 30),
}) {
  final result = Completer<List<int>>();
  final bytes = <int>[];
  StreamSubscription<List<int>>? subscription;
  Timer? timer;
  void fail(Object error) {
    if (result.isCompleted) return;
    result.completeError(error);
    timer?.cancel();
    unawaited(subscription?.cancel());
  }

  subscription = stream.listen(
    (chunk) {
      if (result.isCompleted) return;
      if (bytes.length + chunk.length > limit) {
        fail(
          const IntegrationException(
            'Integration response exceeded its size limit.',
          ),
        );
      } else {
        bytes.addAll(chunk);
      }
    },
    onError: (Object error, StackTrace _) => fail(error),
    onDone: () {
      timer?.cancel();
      if (!result.isCompleted) result.complete(bytes);
    },
  );
  timer = Timer(
    timeout,
    () => fail(const IntegrationException('Integration request timed out.')),
  );
  return result.future;
}

/// Streamable HTTP client: bounded requests; no redirects with bearer tokens.
class McpClient {
  McpClient(this.connection, {http.Client? client})
    : _client = client ?? http.Client();
  final McpConnection connection;
  final http.Client _client;
  String? _session;
  String _version = mcpProtocolVersion;
  int _id = 0;
  bool _closed = false;
  Future<void>? _initializing;
  final _aborts = <Completer<void>>{};

  Future<void> connect() {
    final existing = _initializing;
    if (existing != null) return existing;
    final future = _initialize();
    _initializing = future;
    return future.catchError((Object error, StackTrace stack) {
      if (identical(_initializing, future)) _initializing = null;
      _session = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _initialize() async {
    final result = await _send('initialize', {
      'protocolVersion': mcpProtocolVersion,
      'capabilities': <String, Object>{},
      'clientInfo': {'name': 'zanzibarr', 'version': '1.16.0'},
    });
    final version = result['protocolVersion'];
    if (!_supportedVersions.contains(version)) {
      throw const IntegrationException('Unsupported MCP protocol version.');
    }
    _version = version as String;
    await _send('notifications/initialized', {}, notification: true);
  }

  Future<List<Map<String, dynamic>>> tools() async {
    await connect();
    final tools = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final result = await _send('tools/list', {'cursor': ?cursor});
      final page = result['tools'];
      if (page is! List || tools.length + page.length > 200) {
        throw const IntegrationException(
          'Invalid or oversized MCP tool catalog.',
        );
      }
      for (final tool in page) {
        if (tool is! Map ||
            tool['name'] is! String ||
            tool['inputSchema'] is! Map) {
          throw const IntegrationException('Invalid MCP tool description.');
        }
        tools.add(Map<String, dynamic>.from(tool));
      }
      final next = result['nextCursor'];
      if (next != null && (next is! String || next == cursor || page.isEmpty)) {
        throw const IntegrationException('Invalid MCP pagination cursor.');
      }
      cursor = next as String?;
    } while (cursor != null);
    return tools;
  }

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    await connect();
    return _send('tools/call', {'name': name, 'arguments': arguments});
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Map<String, dynamic> params, {
    bool notification = false,
  }) async {
    if (_closed) throw const IntegrationException('Connection is closed.');
    final id = ++_id;
    final abort = Completer<void>();
    _aborts.add(abort);
    final timer = Timer(const Duration(seconds: 30), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      return await (() async {
        final request = http.AbortableRequest(
          'POST',
          connection.endpoint,
          abortTrigger: abort.future,
        )..followRedirects = false;
        request.headers.addAll({
          'content-type': 'application/json',
          'accept': 'application/json, text/event-stream',
          if (method != 'initialize') 'MCP-Protocol-Version': _version,
          'Mcp-Session-Id': ?_session,
          if (connection.token.isNotEmpty)
            'authorization': 'Bearer ${connection.token}',
        });
        request.body = jsonEncode({
          'jsonrpc': '2.0',
          if (!notification) 'id': id,
          'method': method,
          'params': params,
        });
        final response = await _client.send(request);
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const IntegrationException(
            'MCP authentication failed. Check this connection’s bearer token.',
          );
        }
        if (response.statusCode == 404 && _session != null) {
          // A remote server may expire its session. Reconnect on the next explicit retry.
          _session = null;
          _initializing = null;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const IntegrationException(
            'MCP connection failed. Check its endpoint and availability.',
          );
        }
        if (method == 'initialize') {
          final session = response.headers['mcp-session-id'];
          if (session != null &&
              (session.length > 512 ||
                  !RegExp(r'^[!-~]+$').hasMatch(session))) {
            throw const IntegrationException('Invalid MCP session.');
          }
          _session = session;
        }
        if (notification) {
          await _bounded(response.stream, _maxBody);
          return <String, dynamic>{};
        }
        Map<String, dynamic>? message;
        if (response.headers['content-type']?.startsWith('text/event-stream') ==
            true) {
          var received = 0;
          var data = <String>[];
          await for (final line
              in response.stream
                  .map((chunk) {
                    received += chunk.length;
                    if (received > _maxBody) {
                      throw const IntegrationException(
                        'MCP stream exceeded its size limit.',
                      );
                    }
                    return chunk;
                  })
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())) {
            if (line.isEmpty && data.isNotEmpty) {
              final payload = data.join('\n');
              data = [];
              // Streamable HTTP servers may prime an SSE connection with empty data.
              if (payload.trim().isEmpty) continue;
              final event = jsonDecode(payload);
              if (event is Map &&
                  event['id'] == id &&
                  !event.containsKey('method')) {
                message = Map<String, dynamic>.from(event);
                break;
              }
              if (event is Map &&
                  event.containsKey('id') &&
                  event.containsKey('method')) {
                throw const IntegrationException(
                  'This server requires an unsupported interactive MCP capability.',
                );
              }
            } else if (line.startsWith('data:')) {
              data.add(line.substring(5).trimLeft());
            }
          }
        } else {
          final value = jsonDecode(
            utf8.decode(await _bounded(response.stream, _maxBody)),
          );
          if (value is Map) message = Map<String, dynamic>.from(value);
        }
        if (message == null ||
            message['jsonrpc'] != '2.0' ||
            message['id'] != id) {
          throw const IntegrationException('Invalid MCP response.');
        }
        if (message.containsKey('error')) {
          throw const IntegrationException(
            'The MCP server rejected this request.',
          );
        }
        final result = message['result'];
        if (result is! Map) {
          throw const IntegrationException('Invalid MCP result.');
        }
        return Map<String, dynamic>.from(result);
      })().timeout(const Duration(seconds: 30));
    } on IntegrationException {
      rethrow;
    } catch (_) {
      throw const IntegrationException('MCP request failed or timed out.');
    } finally {
      timer.cancel();
      _aborts.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }

  void close() {
    _closed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
  }
}

typedef McpToolCall =
    Future<Object?> Function(String name, Map<String, dynamic> arguments);

/// Local MCP endpoint is independent of the media/casting HTTP listeners.
class LocalMcpServer {
  LocalMcpServer({
    required this.token,
    required this.tools,
    required this.call,
  });
  final String token;
  final List<Map<String, Object>> Function() tools;
  final McpToolCall call;
  HttpServer? _server;
  int _active = 0;
  bool _closing = false;
  int? get port => _server?.port;

  Future<void> start({int port = 0}) async {
    if (_server != null) return;
    _closing = false;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.idleTimeout = const Duration(seconds: 10);
    _server!.listen((request) => unawaited(_handle(request)));
  }

  Future<void> close() async {
    _closing = true;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    _active++;
    try {
      final host = request.headers.value('host');
      if (_closing || _active > 8) {
        request.response.statusCode = 503;
        return;
      }
      if (request.headers.value('origin') != null ||
          !['127.0.0.1:$port', 'localhost:$port'].contains(host)) {
        request.response.statusCode = 403;
        return;
      }
      if (request.uri.path != '/mcp' || request.uri.hasQuery) {
        request.response.statusCode = 404;
        return;
      }
      if (request.headers.value('authorization') != 'Bearer $token') {
        request.response.statusCode = 401;
        return;
      }
      if (request.method != 'POST') {
        request.response.statusCode = 405;
        request.response.headers.set('allow', 'POST');
        return;
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        request.response.statusCode = 415;
        return;
      }
      final version = request.headers.value('mcp-protocol-version');
      if (version != null && !_supportedVersions.contains(version)) {
        request.response.statusCode = 400;
        return;
      }
      Object? id;
      try {
        final bytes = await _bounded(
          request,
          64 * 1024,
        ).timeout(const Duration(seconds: 5));
        final message = jsonDecode(utf8.decode(bytes));
        if (message is! Map ||
            message['jsonrpc'] != '2.0' ||
            message['method'] is! String ||
            (message.containsKey('id') &&
                message['id'] is! String &&
                message['id'] is! int)) {
          throw const FormatException('Invalid request');
        }
        id = message['id'];
        final method = message['method'];
        if (!message.containsKey('id')) {
          request.response.statusCode = 202;
          return;
        }
        final params = message['params'] ?? <String, dynamic>{};
        if (params is! Map) throw const FormatException('Invalid params');
        Object? result;
        if (method == 'initialize') {
          result = {
            'protocolVersion':
                _supportedVersions.contains(params['protocolVersion'])
                ? params['protocolVersion']
                : mcpProtocolVersion,
            'capabilities': {
              'tools': {'listChanged': false},
            },
            'serverInfo': {'name': 'zanzibarr', 'version': '1.16.0'},
          };
        } else if (method == 'ping') {
          result = <String, Object>{};
        } else if (method == 'tools/list') {
          result = {'tools': tools()};
        } else if (method == 'tools/call') {
          final name = params['name'];
          final args = params['arguments'] ?? <String, dynamic>{};
          if (name is! String || args is! Map) {
            throw const FormatException('Invalid tool arguments');
          }
          try {
            final output = await call(
              name,
              Map<String, dynamic>.from(args),
            ).timeout(const Duration(seconds: 30));
            result = {
              'content': [
                {'type': 'text', 'text': jsonEncode(output)},
              ],
            };
          } catch (_) {
            result = {
              'isError': true,
              'content': [
                {
                  'type': 'text',
                  'text':
                      'Tool unavailable, permission denied, or invalid arguments.',
                },
              ],
            };
          }
        } else {
          _reply(request, {
            'jsonrpc': '2.0',
            'id': id,
            'error': {'code': -32601, 'message': 'Method not found'},
          });
          return;
        }
        if (!_closing) {
          _reply(request, {'jsonrpc': '2.0', 'id': id, 'result': result});
        }
      } catch (_) {
        if (!_closing) {
          _reply(request, {
            'jsonrpc': '2.0',
            'id': id,
            'error': {'code': -32600, 'message': 'Invalid request'},
          });
        }
      }
    } catch (_) {
      // Disconnected clients and shutdown must not surface as unhandled errors.
    } finally {
      _active--;
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  void _reply(HttpRequest request, Map<String, Object?> body) {
    final encoded = utf8.encode(jsonEncode(body));
    if (encoded.length > _maxBody) {
      request.response.statusCode = 500;
      return;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('cache-control', 'no-store');
    request.response.add(encoded);
  }
}
