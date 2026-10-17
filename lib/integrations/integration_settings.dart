import 'dart:convert';
import 'dart:math';

import '../player/media_preferences.dart';

class IntegrationException implements Exception {
  const IntegrationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Endpoints and bearer credentials are kept together in OS secure storage.
class McpConnection {
  const McpConnection({
    required this.id,
    required this.name,
    required this.url,
    this.token = '',
    this.metadata = false,
  });
  final String id;
  final String name;
  final String url;
  final String token;
  final bool metadata;

  Uri get endpoint {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        (uri.scheme == 'http' &&
            !['127.0.0.1', 'localhost', '::1'].contains(uri.host))) {
      throw const IntegrationException(
        'Use HTTPS, or HTTP on localhost, without URL credentials or query parameters.',
      );
    }
    return uri;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'token': token,
    'metadata': metadata,
  };

  factory McpConnection.fromJson(Map<String, dynamic> value) {
    final result = McpConnection(
      id: value['id'] as String,
      name: value['name'] as String,
      url: value['url'] as String,
      token: value['token'] as String? ?? '',
      metadata: value['metadata'] == true,
    );
    result.endpoint;
    if (result.id.isEmpty ||
        result.name.trim().isEmpty ||
        result.name.length > 100 ||
        result.token.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid connection');
    }
    return result;
  }
}

class IntegrationSettings {
  IntegrationSettings({
    this.enabled = false,
    this.allowSearch = false,
    this.allowPlayback = false,
    this.port = 18472,
    String? token,
    this.connections = const [],
    this.codexExecutable = '',
  }) : token = token ?? newIntegrationToken();
  final bool enabled;
  final bool allowSearch;
  final bool allowPlayback;
  final int port;
  final String token;
  final List<McpConnection> connections;
  final String codexExecutable;

  IntegrationSettings copyWith({
    bool? enabled,
    bool? allowSearch,
    bool? allowPlayback,
    int? port,
    String? token,
    List<McpConnection>? connections,
    String? codexExecutable,
  }) => IntegrationSettings(
    enabled: enabled ?? this.enabled,
    allowSearch: allowSearch ?? this.allowSearch,
    allowPlayback: allowPlayback ?? this.allowPlayback,
    port: port ?? this.port,
    token: token ?? this.token,
    connections: connections ?? this.connections,
    codexExecutable: codexExecutable ?? this.codexExecutable,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'enabled': enabled,
    'allowSearch': allowSearch,
    'allowPlayback': allowPlayback,
    'port': port,
    'token': token,
    'connections': [for (final c in connections) c.toJson()],
    'codexExecutable': codexExecutable,
  };

  factory IntegrationSettings.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['enabled'] is! bool ||
        json['allowSearch'] is! bool ||
        json['allowPlayback'] is! bool) {
      throw const FormatException('Unsupported settings');
    }
    final result = IntegrationSettings(
      enabled: json['enabled'] == true,
      allowSearch: json['allowSearch'] == true,
      allowPlayback: json['allowPlayback'] == true,
      port: json['port'] as int,
      token: json['token'] as String,
      connections: [
        for (final c in json['connections'] as List)
          McpConnection.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
      codexExecutable: json['codexExecutable'] as String? ?? '',
    );
    if (result.port < 1024 ||
        result.port > 65535 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(result.token) ||
        result.connections.length > 20 ||
        result.connections.map((c) => c.id).toSet().length !=
            result.connections.length) {
      throw const FormatException('Invalid settings');
    }
    return result;
  }
}

String newIntegrationToken() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class IntegrationStore {
  IntegrationStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage _storage;
  static const key = 'zanzibarr.integrations.v1';

  Future<IntegrationSettings> load() async {
    final value = await _storage.read(key);
    if (value == null) return IntegrationSettings();
    try {
      return IntegrationSettings.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const IntegrationException(
        'Integrations could not be loaded. Existing settings were preserved.',
      );
    }
  }

  Future<void> save(IntegrationSettings settings) async {
    // Validate before committing the single secure-storage value.
    IntegrationSettings.fromJson(settings.toJson());
    await _storage.write(key, jsonEncode(settings.toJson()));
  }
}
