import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../integrations/integration_settings.dart';

/// One bounded, cancellable request; credentials never follow redirects.
class AiHttp {
  AiHttp({http.Client Function()? clientFactory})
    : _factory = clientFactory ?? http.Client.new;
  final http.Client Function() _factory;
  final _active = <http.Client, Completer<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> post(
    Uri uri, {
    required String service,
    Map<String, String> headers = const {},
    Object? json,
    Map<String, String>? form,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final client = _factory();
    final cancelled = Completer<Map<String, dynamic>>();
    _active[client] = cancelled;
    try {
      final request = http.Request('POST', uri)..followRedirects = false;
      request.headers.addAll(headers);
      if (form != null) {
        request.bodyFields = form;
      } else {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(json);
      }
      return await Future.any([
        _read(client, request, service),
        cancelled.future,
      ]).timeout(timeout);
    } on IntegrationException {
      rethrow;
    } on TimeoutException {
      throw IntegrationException('$service timed out. Please retry.');
    } catch (_) {
      throw IntegrationException(
        '$service could not be reached or returned an invalid response. Please retry.',
      );
    } finally {
      _active.remove(client);
      client.close();
    }
  }

  Future<Map<String, dynamic>> _read(
    http.Client client,
    http.Request request,
    String service,
  ) async {
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final advice = switch (response.statusCode) {
        401 || 403 =>
          'Check your API credentials, Google sign-in and project permissions.',
        429 => 'Your API quota or rate limit was reached. Try again later.',
        400 || 404 => 'Check the model ID and connection settings.',
        >= 300 && < 400 => 'Redirects are not accepted.',
        _ => 'The service is unavailable. Try again later.',
      };
      throw IntegrationException(
        '$service request failed (${response.statusCode}). $advice',
      );
    }
    if ((response.contentLength ?? 0) > 512 * 1024) {
      throw IntegrationException(
        '$service response was too large. Ask for fewer films.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 512 * 1024) {
        throw IntegrationException(
          '$service response was too large. Ask for fewer films.',
        );
      }
      bytes.addAll(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid response');
    }
    return decoded;
  }

  void cancel() {
    for (final entry in _active.entries.toList()) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          const IntegrationException(
            'Request stopped. Your draft is kept for retry.',
          ),
        );
      }
      entry.key.close();
    }
    _active.clear();
  }
}
