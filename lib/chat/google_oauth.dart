import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import '../integrations/integration_settings.dart';
import 'ai_connections.dart';
import 'ai_http.dart';

/// Registered desktop OAuth client, external browser, loopback callback and PKCE.
/// No CLI credentials or Google browser sessions are read.
class GoogleOAuth {
  GoogleOAuth({AiHttp? http, this.timeout = const Duration(minutes: 5)})
    : http = http ?? AiHttp();
  final AiHttp http;
  final Duration timeout;
  HttpServer? _server;
  Completer<String>? _code;
  bool _busy = false;
  int _generation = 0;
  static final tokenEndpoint = Uri.https('oauth2.googleapis.com', '/token');
  static String _random() => base64Url
      .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');

  Future<GoogleTokens> signIn(
    AiConnections config,
    Future<bool> Function(Uri) launch,
  ) async {
    if (_busy) {
      throw const IntegrationException('Google sign-in is already open.');
    }
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      throw const IntegrationException(
        'Google browser sign-in currently supports desktop apps. Use a Gemini API key on this device.',
      );
    }
    config.validateGoogleClient();
    _busy = true;
    final generation = ++_generation;
    final code = Completer<String>();
    _code = code;
    // Cancellation may happen while binding or opening the browser.
    unawaited(code.future.catchError((Object _) => ''));
    HttpServer? server;
    StreamSubscription<HttpRequest>? requests;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (generation != _generation) {
        throw const IntegrationException('Google sign-in cancelled.');
      }
      _server = server;
      final redirect = Uri.parse(
        'http://127.0.0.1:${server.port}/oauth/callback',
      );
      final state = _random();
      final verifier = _random();
      final challenge = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      requests = server.listen(
        (request) async {
          try {
            request.response.headers
              ..contentType = ContentType.text
              ..set('cache-control', 'no-store')
              ..set('referrer-policy', 'no-referrer');
            final query = request.uri.queryParametersAll;
            final valid =
                request.method == 'GET' &&
                request.uri.path == redirect.path &&
                request.uri.toString().length <= 16384 &&
                query.values.every((values) => values.length == 1) &&
                query['state']?.single == state &&
                (!query.containsKey('iss') ||
                    [
                      'https://accounts.google.com',
                      'accounts.google.com',
                    ].contains(query['iss']?.single));
            if (!valid || code.isCompleted) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.write(
                'Invalid or expired sign-in request. Return to Zanzibarr.',
              );
            } else if (query.containsKey('error')) {
              request.response.write(
                'Sign-in was not completed. Return to Zanzibarr.',
              );
              code.completeError(
                const IntegrationException(
                  'Google sign-in was declined or could not finish. Please retry.',
                ),
              );
            } else if (query['code']?.single.isNotEmpty == true) {
              request.response.write(
                'You can return to Zanzibarr to finish connecting.',
              );
              code.complete(query['code']!.single);
            } else {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.write(
                'Missing sign-in response. Return to Zanzibarr.',
              );
            }
            try {
              await request.response.close();
            } catch (_) {}
          } catch (_) {
            try {
              request.response.statusCode = HttpStatus.badRequest;
              await request.response.close();
            } catch (_) {}
          }
        },
        onError: (Object _) {
          if (!code.isCompleted) {
            code.completeError(
              const IntegrationException(
                'Google callback failed. Please retry.',
              ),
            );
          }
        },
      );
      final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': config.googleClientId,
        'redirect_uri': redirect.toString(),
        'response_type': 'code',
        'scope':
            'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/generative-language.retriever',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });
      final opened = await Future.any([
        launch(uri),
        code.future.then((_) => true),
      ]).timeout(const Duration(seconds: 30));
      if (!opened) {
        throw const IntegrationException(
          'Could not open your browser. Please retry Google sign-in.',
        );
      }
      final authorizationCode = await code.future.timeout(timeout);
      if (generation != _generation) {
        throw const IntegrationException('Google sign-in cancelled.');
      }
      final result = await http.post(
        tokenEndpoint,
        service: 'Google sign-in',
        timeout: const Duration(seconds: 30),
        form: {
          'client_id': config.googleClientId,
          if (config.googleClientSecret.isNotEmpty)
            'client_secret': config.googleClientSecret,
          'code': authorizationCode,
          'code_verifier': verifier,
          'redirect_uri': redirect.toString(),
          'grant_type': 'authorization_code',
        },
      );
      if (generation != _generation) {
        throw const IntegrationException('Google sign-in cancelled.');
      }
      return _tokens(result);
    } on IntegrationException {
      rethrow;
    } on TimeoutException {
      throw const IntegrationException(
        'Google sign-in timed out. Please try again.',
      );
    } catch (_) {
      throw const IntegrationException(
        'Google sign-in could not finish. Check your Desktop OAuth client setup and try again.',
      );
    } finally {
      await requests?.cancel();
      await server?.close(force: true);
      if (identical(_server, server)) _server = null;
      if (identical(_code, code)) _code = null;
      _busy = false;
    }
  }

  Future<GoogleTokens> refresh(AiConnections config) async {
    config.validateGoogleClient();
    final previous = config.googleTokens;
    if (previous == null || previous.refresh.isEmpty) {
      throw const IntegrationException(
        'Sign in with Google in AI connections first.',
      );
    }
    final result = await http.post(
      tokenEndpoint,
      service: 'Google token refresh',
      timeout: const Duration(seconds: 30),
      form: {
        'client_id': config.googleClientId,
        if (config.googleClientSecret.isNotEmpty)
          'client_secret': config.googleClientSecret,
        'refresh_token': previous.refresh,
        'grant_type': 'refresh_token',
      },
    );
    return _tokens(result, previousRefresh: previous.refresh);
  }

  GoogleTokens _tokens(Map<String, dynamic> result, {String? previousRefresh}) {
    final access = result['access_token'];
    final refresh = result['refresh_token'] ?? previousRefresh;
    final expires = result['expires_in'];
    if (result['token_type']?.toString().toLowerCase() != 'bearer' ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expires is! int ||
        expires < 1 ||
        expires > 604800) {
      throw const IntegrationException(
        'Google did not return a reusable sign-in. Try signing in again and allow offline access.',
      );
    }
    try {
      return GoogleTokens.fromJson({
        'access': access,
        'refresh': refresh,
        'expiresAt': DateTime.now()
            .add(Duration(seconds: expires))
            .toUtc()
            .toIso8601String(),
      });
    } catch (_) {
      throw const IntegrationException(
        'Google returned an invalid sign-in response.',
      );
    }
  }

  void cancel() {
    ++_generation;
    final code = _code;
    if (code != null && !code.isCompleted) {
      code.completeError(
        const IntegrationException('Google sign-in cancelled.'),
      );
    }
    http.cancel();
    unawaited(_server?.close(force: true));
  }
}
