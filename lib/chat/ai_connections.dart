import 'dart:convert';

import '../integrations/integration_settings.dart';
import '../player/media_preferences.dart';

enum FilmAiProvider { codex, claude, gemini }

extension FilmAiProviderName on FilmAiProvider {
  String get label => switch (this) {
    FilmAiProvider.codex => 'ChatGPT through Codex',
    FilmAiProvider.claude => 'Claude API',
    FilmAiProvider.gemini => 'Gemini API',
  };
}

enum GeminiAuthentication { apiKey, google }

// Credential-bearing objects deliberately have no diagnostic serialization.
class GoogleTokens {
  const GoogleTokens(this.access, this.refresh, this.expiresAt);
  final String access;
  final String refresh;
  final DateTime expiresAt;
  bool get fresh =>
      expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)));
  Map<String, Object> toJson() => {
    'access': access,
    'refresh': refresh,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
  factory GoogleTokens.fromJson(Map<String, dynamic> json) {
    final access = _credential(json['access']);
    final refresh = _credential(json['refresh']);
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException('Missing Google credentials');
    }
    return GoogleTokens(
      access,
      refresh,
      DateTime.parse(json['expiresAt'] as String),
    );
  }
}

String _credential(Object? value) {
  if (value is! String ||
      value.length > 8192 ||
      value.contains(RegExp(r'[\x00-\x20\x7f]'))) {
    throw const FormatException('Invalid credential');
  }
  return value;
}

class AiConnections {
  const AiConnections({
    this.provider = FilmAiProvider.codex,
    this.claudeKey = '',
    this.claudeModel = 'claude-sonnet-4-6',
    this.geminiKey = '',
    this.geminiModel = 'gemini-3.8-flash',
    this.geminiAuthentication = GeminiAuthentication.apiKey,
    this.googleClientId = '',
    this.googleClientSecret = '',
    this.googleProject = '',
    this.googleTokens,
    this.liveResearch = false,
  });
  final FilmAiProvider provider;
  final bool liveResearch;
  final String claudeKey, claudeModel, geminiKey, geminiModel;
  final GeminiAuthentication geminiAuthentication;
  final String googleClientId, googleClientSecret, googleProject;
  final GoogleTokens? googleTokens;

  AiConnections copyWith({
    FilmAiProvider? provider,
    bool? liveResearch,
    String? claudeKey,
    String? claudeModel,
    String? geminiKey,
    String? geminiModel,
    GeminiAuthentication? geminiAuthentication,
    String? googleClientId,
    String? googleClientSecret,
    String? googleProject,
    GoogleTokens? googleTokens,
    bool clearGoogleTokens = false,
  }) {
    final changedClient =
        (googleClientId != null && googleClientId != this.googleClientId) ||
        (googleClientSecret != null &&
            googleClientSecret != this.googleClientSecret) ||
        (googleProject != null && googleProject != this.googleProject);
    return AiConnections(
      provider: provider ?? this.provider,
      liveResearch: liveResearch ?? this.liveResearch,
      claudeKey: claudeKey ?? this.claudeKey,
      claudeModel: claudeModel ?? this.claudeModel,
      geminiKey: geminiKey ?? this.geminiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      geminiAuthentication: geminiAuthentication ?? this.geminiAuthentication,
      googleClientId: googleClientId ?? this.googleClientId,
      googleClientSecret: googleClientSecret ?? this.googleClientSecret,
      googleProject: googleProject ?? this.googleProject,
      googleTokens: clearGoogleTokens || changedClient
          ? null
          : googleTokens ?? this.googleTokens,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'provider': provider.name,
    'liveResearch': liveResearch,
    'claudeKey': claudeKey,
    'claudeModel': claudeModel,
    'geminiKey': geminiKey,
    'geminiModel': geminiModel,
    'geminiAuthentication': geminiAuthentication.name,
    'googleClientId': googleClientId,
    'googleClientSecret': googleClientSecret,
    'googleProject': googleProject,
    'googleTokens': googleTokens?.toJson(),
  };
  factory AiConnections.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported settings');
    }
    if (json.containsKey('liveResearch') && json['liveResearch'] is! bool) {
      throw const FormatException('Invalid research setting');
    }
    final result = AiConnections(
      provider: FilmAiProvider.values.byName(json['provider'] as String),
      liveResearch: json['liveResearch'] == true,
      claudeKey: _credential(json['claudeKey']),
      claudeModel: json['claudeModel'] as String,
      geminiKey: _credential(json['geminiKey']),
      geminiModel: json['geminiModel'] as String,
      geminiAuthentication: GeminiAuthentication.values.byName(
        json['geminiAuthentication'] as String,
      ),
      googleClientId: _credential(json['googleClientId']),
      googleClientSecret: _credential(json['googleClientSecret']),
      googleProject: _credential(json['googleProject']),
      googleTokens: json['googleTokens'] == null
          ? null
          : GoogleTokens.fromJson(
              Map<String, dynamic>.from(json['googleTokens'] as Map),
            ),
    );
    final model = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$');
    if (!model.hasMatch(result.claudeModel) ||
        !model.hasMatch(result.geminiModel)) {
      throw const FormatException('Invalid model');
    }
    return result;
  }

  void validateGoogleClient() {
    if (!RegExp(
          r'^[a-zA-Z0-9.-]+\.apps\.googleusercontent\.com$',
        ).hasMatch(googleClientId) ||
        !RegExp(r'^[a-z][a-z0-9-]{4,61}[a-z0-9]$').hasMatch(googleProject)) {
      throw const IntegrationException(
        'Enter your Google Desktop OAuth client ID and Cloud project ID first.',
      );
    }
  }
}

class AiConnectionStore {
  AiConnectionStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage _storage;
  static const key = 'zanzibarr.ai-connections.v1';

  Future<AiConnections> load() async {
    try {
      final value = await _storage.read(key);
      if (value == null) return const AiConnections();
      if (value.length > 100000) throw const FormatException('Too large');
      return AiConnections.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      throw const IntegrationException(
        'AI connections could not be loaded. Saved credentials were preserved. Retry to continue.',
      );
    }
  }

  Future<void> save(AiConnections value) async {
    try {
      AiConnections.fromJson(value.toJson());
      await _storage.write(key, jsonEncode(value.toJson()));
    } catch (_) {
      throw const IntegrationException(
        'Could not save AI connections. Check the model IDs and secure storage, then retry.',
      );
    }
  }

  Future<AiConnections> updateGoogleTokens(
    AiConnections expected,
    GoogleTokens tokens,
  ) async {
    final current = await load();
    if (current.googleClientId != expected.googleClientId ||
        current.googleClientSecret != expected.googleClientSecret ||
        current.googleProject != expected.googleProject ||
        current.googleTokens?.refresh != expected.googleTokens?.refresh) {
      throw const IntegrationException(
        'Google connection changed. Please retry.',
      );
    }
    final updated = current.copyWith(googleTokens: tokens);
    await save(updated);
    return updated;
  }
}
