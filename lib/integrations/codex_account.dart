import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'integration_settings.dart';

/// Managed Codex RPC. Zanzibarr never reads, exports or stores OAuth tokens.
class CodexRpc {
  CodexRpc(Stream<Map<String, dynamic>> messages, this.send, this.close) {
    _subscription = messages.listen(
      _receive,
      onError: (Object _) => _failed(),
      onDone: _failed,
    );
  }
  final void Function(Map<String, Object?> message) send;
  final Future<void> Function() close;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _id = 0;
  bool _closed = false;
  Future<void>? _disposing;

  static Future<String?> discoverExecutable() async {
    final local = Platform.environment['LOCALAPPDATA'];
    final candidates = [
      if (Platform.isWindows && local != null)
        '$local/Programs/OpenAI/Codex/bin/codex.exe',
      for (final directory in (Platform.environment['PATH'] ?? '').split(
        Platform.isWindows ? ';' : ':',
      ))
        if (directory.isNotEmpty)
          '$directory/${Platform.isWindows ? 'codex.exe' : 'codex'}',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  static Future<CodexRpc> start(String executable) async {
    if (executable.trim().isEmpty) {
      throw const IntegrationException(
        'Choose the official Codex executable first.',
      );
    }
    final support = await getApplicationSupportDirectory();
    final home = await Directory(
      '${support.path}/codex-account',
    ).create(recursive: true);
    final process = await Process.start(
      executable,
      [
        'app-server',
        '--listen',
        'stdio://',
        '-c',
        'cli_auth_credentials_store="keyring"',
      ],
      runInShell: false,
      workingDirectory: home.path,
      environment: {
        'CODEX_HOME': home.path,
        'OPENAI_API_KEY': '',
        'CODEX_API_KEY': '',
      },
    );
    final stderr = process.stderr.listen((_) {});
    unawaited(process.stdin.done.catchError((Object _) {}));
    return CodexRpc(
      decodeMessages(process.stdout),
      (message) {
        process.stdin.writeln(jsonEncode(message));
      },
      () async {
        await stderr.cancel();
        try {
          await process.stdin.close();
        } catch (_) {}
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 3));
        } catch (_) {
          process.kill(ProcessSignal.sigkill);
        }
      },
    );
  }

  @visibleForTesting
  static Stream<Map<String, dynamic>> decodeMessages(
    Stream<List<int>> stream,
  ) async* {
    var buffer = <int>[];
    await for (final chunk in stream) {
      for (final byte in chunk) {
        if (byte == 10) {
          if (buffer.isNotEmpty) {
            final value = jsonDecode(utf8.decode(buffer));
            if (value is! Map) {
              throw const FormatException('Invalid Codex message');
            }
            yield Map<String, dynamic>.from(value);
          }
          buffer = [];
        } else {
          if (buffer.length >= 2 * 1024 * 1024) {
            throw const FormatException('Codex message too large');
          }
          buffer.add(byte);
        }
      }
    }
  }

  void _receive(Map<String, dynamic> message) {
    final id = message['id'];
    final method = message['method'];
    if (method is String && id == null) {
      _notifications.add(message);
    } else if (method is String && id != null) {
      // Film chat never grants tool execution or agent approvals.
      send({
        'id': id,
        'error': {'code': -32601, 'message': 'Unsupported request'},
      });
    } else if (id is int) {
      final pending = _pending.remove(id);
      if (pending == null) return;
      final result = message['result'];
      if (message.containsKey('error') || result is! Map) {
        pending.completeError(
          const IntegrationException(
            'Codex rejected the request. Update Codex or try signing in again.',
          ),
        );
      } else {
        pending.complete(Map<String, dynamic>.from(result));
      }
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, Object?> params,
  ) async {
    if (_closed) throw const IntegrationException('Codex is disconnected.');
    final id = ++_id;
    final result = Completer<Map<String, dynamic>>();
    _pending[id] = result;
    try {
      send({'id': id, 'method': method, 'params': params});
      return await result.future.timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const IntegrationException('Codex request failed or timed out.');
    } finally {
      _pending.remove(id);
    }
  }

  void _failed() {
    if (_closed) return;
    _closed = true;
    if (!_notifications.isClosed) {
      _notifications.add({'method': 'zanzibarr/disconnected'});
    }
    for (final pending in _pending.values) {
      pending.completeError(const IntegrationException('Codex disconnected.'));
    }
    _pending.clear();
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _failed();
    // The async decoder may be waiting for a silent child's next pipe chunk.
    // Close the process/pipe first so cancelling that decoder can complete.
    try {
      await close();
    } finally {
      await _subscription.cancel();
      await _notifications.close();
    }
  }
}

class CodexAccount extends ChangeNotifier {
  CodexAccount({Future<CodexRpc> Function(String)? start})
    : _start = start ?? CodexRpc.start;
  final Future<CodexRpc> Function(String) _start;
  CodexRpc? _rpc;
  StreamSubscription<Map<String, dynamic>>? _events;
  String? plan;
  String? error;
  bool connected = false;
  bool signingIn = false;
  String? _loginId;
  bool _disposed = false;
  Timer? _loginTimer;
  Future<void>? _connecting;
  int _connectionEpoch = 0;
  CodexRpc? get rpc => _rpc;

  Future<void> disconnect() async {
    ++_connectionEpoch;
    _loginTimer?.cancel();
    _loginId = null;
    signingIn = false;
    connected = false;
    _connecting = null;
    final events = _events;
    _events = null;
    final rpc = _rpc;
    _rpc = null;
    await events?.cancel();
    await rpc?.dispose();
    _notify();
  }

  Future<void> connect(String executable) =>
      _connecting ??= _connect(executable);
  Future<void> _connect(String executable) async {
    final epoch = ++_connectionEpoch;
    CodexRpc? opened;
    var step = 'start Codex';
    try {
      await _events?.cancel();
      await _rpc?.dispose();
      final rpc = await _start(executable);
      opened = rpc;
      if (_disposed || epoch != _connectionEpoch) {
        await rpc.dispose();
        return;
      }
      _rpc = rpc;
      _events = rpc.notifications.listen((event) {
        if (epoch != _connectionEpoch) return;
        if (event['method'] == 'zanzibarr/disconnected') {
          connected = false;
          signingIn = false;
          _connecting = null;
          error = 'Codex disconnected. Reconnect to continue.';
          _notify();
        } else if (event['method'] == 'account/login/completed') {
          final params = event['params'];
          error = params is Map && params['success'] == true
              ? null
              : 'Codex sign-in did not complete. Please try again.';
          signingIn = false;
          _loginId = null;
          _loginTimer?.cancel();
          _notify();
          unawaited(
            refresh().catchError((Object _) {
              if (epoch != _connectionEpoch || _disposed) return;
              error =
                  'Could not check the signed-in account. Reconnect to retry.';
              _notify();
            }),
          );
        } else if (event['method'] == 'account/updated') {
          final params = event['params'];
          if (params is Map) {
            connected = params['authMode'] == 'chatgpt';
            plan = params['planType'] is String
                ? params['planType'] as String
                : null;
            _notify();
          }
        }
      });
      step = 'initialize Codex';
      await rpc.request('initialize', {
        'clientInfo': {
          'name': 'zanzibarr',
          'title': 'Zanzibarr',
          'version': '1.16.0',
        },
      });
      rpc.send({'method': 'initialized', 'params': <String, Object>{}});
      step = 'read the Codex account';
      await refresh();
      if (_disposed || epoch != _connectionEpoch) return;
      error = null;
      _notify();
    } catch (failure) {
      if (_disposed || epoch != _connectionEpoch) {
        await opened?.dispose();
        return;
      }
      _connecting = null;
      await _events?.cancel();
      await _rpc?.dispose();
      _rpc = null;
      final message = switch (failure) {
        ProcessException() =>
          'Could not start Codex (system error ${failure.errorCode}). Check the executable path and that Windows allows it to run.',
        FileSystemException() =>
          'Could not prepare the local Codex profile. Check access to the application data folder and retry.',
        IntegrationException() => 'Could not $step. ${failure.message}',
        _ => 'Could not $step (${failure.runtimeType}). Please retry.',
      };
      throw IntegrationException(message);
    }
  }

  Future<void> refresh() async {
    final rpc = _rpc;
    if (rpc == null) return;
    final result = await rpc.request('account/read', {'refreshToken': false});
    if (_disposed || !identical(rpc, _rpc)) return;
    final account = result['account'];
    connected = account is Map && account['type'] == 'chatgpt';
    if (connected) error = null;
    plan = account is Map && account['planType'] is String
        ? account['planType'] as String
        : null;
    _notify();
  }

  Future<Uri> signIn() async {
    if (signingIn || _rpc == null) {
      throw const IntegrationException('Connect to Codex first.');
    }
    signingIn = true;
    error = null;
    _notify();
    try {
      final result = await _rpc!.request('account/login/start', {
        'type': 'chatgpt',
      });
      final url = Uri.tryParse(
        result['authUrl'] is String ? result['authUrl'] as String : '',
      );
      if (url == null ||
          url.scheme != 'https' ||
          url.userInfo.isNotEmpty ||
          !['auth.openai.com', 'chatgpt.com'].contains(url.host) ||
          result['loginId'] is! String) {
        throw const IntegrationException(
          'Codex returned an invalid sign-in link.',
        );
      }
      _loginId = result['loginId'] as String;
      _loginTimer = Timer(
        const Duration(minutes: 10),
        () => unawaited(cancelSignIn().catchError((Object _) {})),
      );
      return url;
    } catch (_) {
      signingIn = false;
      _notify();
      rethrow;
    }
  }

  Future<void> cancelSignIn() async {
    final id = _loginId;
    if (id != null) {
      await _rpc?.request('account/login/cancel', {'loginId': id});
    }
    _loginId = null;
    signingIn = false;
    _loginTimer?.cancel();
    _notify();
  }

  Future<void> signOut() async {
    await cancelSignIn();
    await _rpc?.request('account/logout', {});
    connected = false;
    plan = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_connectionEpoch;
    _loginTimer?.cancel();
    unawaited(_events?.cancel());
    final rpc = _rpc;
    if (rpc != null) {
      unawaited(() async {
        try {
          if (_loginId != null) {
            await rpc.request('account/login/cancel', {'loginId': _loginId});
          }
        } catch (_) {}
        await rpc.dispose();
      }());
    }
    super.dispose();
  }
}
