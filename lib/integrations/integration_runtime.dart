import 'dart:async';
import 'package:flutter/foundation.dart';

import '../player/playback_history.dart';
import '../settings/indexer_settings.dart';
import '../src/rust/api/search.dart';
import 'integration_settings.dart';
import 'mcp_transport.dart';
import 'mcp_call_context.dart';

class IntegrationPlayback {
  IntegrationPlayback({
    required this.status,
    required this.pause,
    required this.resume,
    required this.seek,
  });
  final Map<String, Object?> Function() status;
  final Future<void> Function(void Function() authorize) pause;
  final Future<void> Function(void Function() authorize) resume;
  final Future<void> Function(Duration position, void Function() authorize)
  seek;
}

class IntegrationRuntime extends ChangeNotifier {
  IntegrationRuntime({
    IntegrationStore? store,
    Future<Object?> Function()? library,
    Future<Object?> Function(String query)? search,
  }) : store = store ?? IntegrationStore(),
       _library = library ?? _loadLibrary,
       _search = search ?? _searchReleases;
  static final instance = IntegrationRuntime();
  final IntegrationStore store;
  final Future<Object?> Function() _library;
  final Future<Object?> Function(String) _search;
  IntegrationSettings? settings;
  String? error;
  LocalMcpServer? _server;
  Future<void>? _loading;
  bool _saving = false;
  IntegrationPlayback? _playback;
  bool get running => _server?.port != null;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      settings = await store.load();
      await _start();
    } catch (_) {
      error =
          'Integrations could not be loaded or started. Open Integrations to retry.';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _loading = null;
    error = null;
    await load();
  }

  Future<void> save(IntegrationSettings next) async {
    if (_saving) {
      throw const IntegrationException(
        'An integration change is already being saved.',
      );
    }
    _saving = true;
    try {
      await store.save(next);
      settings = next;
      await _server?.close();
      _server = null;
      await _start();
      error = null;
    } catch (_) {
      error =
          'Could not save or start integrations. Check storage and whether the port is already in use.';
      throw IntegrationException(error!);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _start() async {
    final config = settings;
    if (config == null || !config.enabled || running) return;
    final server = LocalMcpServer(
      token: config.token,
      tools: tools,
      call: (name, arguments, context) =>
          call(name, arguments, context: context),
    );
    try {
      await server.start(port: config.port);
      _server = server;
    } catch (_) {
      await server.close();
      rethrow;
    }
  }

  void attachPlayback(IntegrationPlayback playback) {
    _playback = playback;
  }

  void detachPlayback(IntegrationPlayback playback) {
    if (identical(_playback, playback)) _playback = null;
  }

  List<Map<String, Object>> tools() {
    final config = settings;
    Map<String, Object> tool(
      String name,
      String description, [
      Map<String, Object> properties = const {},
      List<String> required = const [],
    ]) => {
      'name': name,
      'description': description,
      'inputSchema': {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': false,
      },
      'annotations': {
        'readOnlyHint':
            !name.startsWith('playback_') || name == 'playback_status',
        'destructiveHint': false,
        'openWorldHint': name == 'search_releases',
      },
    };
    return [
      tool(
        'library_list',
        'List watched/resumable media without file paths or source URLs.',
      ),
      tool('playback_status', 'Read active playback status.'),
      if (config?.allowSearch == true)
        tool(
          'search_releases',
          'Search enabled indexers. Does not download or play.',
          {
            'query': {'type': 'string', 'minLength': 1, 'maxLength': 200},
          },
          ['query'],
        ),
      if (config?.allowPlayback == true) ...[
        tool('playback_pause', 'Pause active playback.'),
        tool('playback_resume', 'Resume active playback.'),
        tool(
          'playback_seek',
          'Seek active playback to an absolute position in seconds.',
          {
            'seconds': {'type': 'number', 'minimum': 0},
          },
          ['seconds'],
        ),
      ],
    ];
  }

  void _authorize(String name, McpCallContext? context) {
    context?.check();
    final config = settings;
    if (config?.enabled != true) {
      throw const IntegrationException('MCP access is disabled.');
    }
    if (!tools().any((tool) => tool['name'] == name)) {
      throw const IntegrationException('Tool is not allowed.');
    }
  }

  Future<Object?> call(
    String name,
    Map<String, dynamic> arguments, {
    McpCallContext? context,
  }) async {
    _authorize(name, context);
    final allowed = name == 'search_releases'
        ? {'query'}
        : name == 'playback_seek'
        ? {'seconds'}
        : <String>{};
    if (arguments.keys.any((key) => !allowed.contains(key))) {
      throw const IntegrationException('Unknown tool argument.');
    }
    if (name == 'library_list') {
      final result = await _library();
      _authorize(name, context);
      return result;
    }
    if (name == 'search_releases') {
      final query = arguments['query'];
      if (query is! String || query.trim().isEmpty || query.length > 200) {
        throw const IntegrationException('Invalid search query.');
      }
      final result = await _search(query.trim());
      _authorize(name, context);
      return result;
    }
    final playback = _playback;
    if (name == 'playback_status') {
      return playback?.status() ?? {'active': false};
    }
    if (playback == null) throw const IntegrationException('No active player.');
    void authorize() {
      _authorize(name, context);
      if (!identical(_playback, playback)) {
        throw const IntegrationException('Player is no longer active.');
      }
    }

    authorize();
    switch (name) {
      case 'playback_pause':
        await playback.pause(authorize);
      case 'playback_resume':
        await playback.resume(authorize);
      case 'playback_seek':
        final seconds = arguments['seconds'];
        final duration = playback.status()['durationSeconds'];
        if (seconds is! num ||
            !seconds.isFinite ||
            seconds < 0 ||
            duration is! num ||
            duration <= 0 ||
            seconds > duration) {
          throw const IntegrationException(
            'Seek must be within the active media duration.',
          );
        }
        await playback.seek(
          Duration(milliseconds: (seconds * 1000).round()),
          authorize,
        );
    }
    authorize();
    return playback.status();
  }

  static Future<Object?> _loadLibrary() async => [
    for (final entry in await PlaybackHistoryStore().load())
      {
        'title': entry.title,
        'imdbId': entry.imdbId,
        'season': entry.season,
        'episode': entry.episode,
        'positionSeconds': entry.positionSeconds,
        'durationSeconds': entry.durationSeconds,
        'completed': entry.isCompleted,
        'favorite': entry.favorite,
      },
  ];

  static Future<Object?> _searchReleases(String query) async {
    final profiles = await IndexerSettingsStore().load();
    final configs = [
      for (final p in profiles)
        if (p.enabled && p.isComplete)
          IndexerConfigDto(
            id: p.id,
            baseUrl: p.baseUrl,
            apiKey: p.apiKey,
            nickname: p.nickname,
          ),
    ];
    if (configs.isEmpty) {
      throw const IntegrationException('Configure an indexer first.');
    }
    final response = await newznabSearchMany(
      configs: configs,
      query: query,
      limit: 25,
      offset: 0,
    );
    // Never expose credential-bearing download URLs, info URLs or native errors.
    return {
      'items': [
        for (final item in response.page.items.take(100))
          {
            'title': item.title,
            'sizeBytes': item.sizeBytes?.toString(),
            'badges': item.badges,
            'kind': item.mediaKind,
            'season': item.season,
            'episode': item.episode,
            'year': item.year,
          },
      ],
      'partialFailure': response.failedIndexers.isNotEmpty,
    };
  }

  Future<void> shutdown() async {
    await _server?.close();
    _server = null;
  }
}
