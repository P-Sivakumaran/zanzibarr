import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/film_chat_screen.dart';
import '../chat/ai_connections_screen.dart';
import '../search/search_screen.dart';
import 'codex_account.dart';
import 'integration_runtime.dart';
import 'integration_settings.dart';
import 'mcp_transport.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({
    super.key,
    this.runtime,
    this.discoverCodex = CodexRpc.discoverExecutable,
  });
  final Future<String?> Function() discoverCodex;
  final IntegrationRuntime? runtime;
  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  late final runtime = widget.runtime ?? IntegrationRuntime.instance;
  final _executable = TextEditingController();
  CodexAccount? _codex;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    runtime.addListener(_changed);
    _run(() async {
      await runtime.load();
      final saved = runtime.settings?.codexExecutable ?? '';
      final path = saved.isEmpty ? await widget.discoverCodex() ?? '' : saved;
      if (mounted) _executable.text = path;
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    runtime.removeListener(_changed);
    _executable.dispose();
    _codex?.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is IntegrationException
              ? error.message
              : 'Integration action failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final config = runtime.settings;
    if (config == null) return;
    await runtime.save(
      config.copyWith(codexExecutable: _executable.text.trim()),
    );
    final account = _codex ??= CodexAccount()..addListener(_changed);
    await account.connect(_executable.text.trim());
    if (!mounted || account.connected) return;
    final url = await account.signIn();
    if (!mounted) return;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await account.cancelSignIn();
      throw const IntegrationException('Could not open the sign-in browser.');
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = runtime.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Integration controls currently use English. Connections are optional; search and playback work without them.',
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null || runtime.error != null) ...[
                Text(
                  _error ?? runtime.error!,
                  key: const Key('integration-error'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _run(runtime.retry),
                  child: const Text('Retry'),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: const Key('integration-sign-in'),
                  onPressed:
                      _busy || config == null || _codex?.signingIn == true
                      ? null
                      : () => _run(_signIn),
                  icon: const Icon(Icons.login),
                  label: Text(
                    _codex?.connected == true
                        ? 'ChatGPT connected'
                        : _codex?.signingIn == true
                        ? 'Finish browser sign-in'
                        : 'Sign in with ChatGPT',
                  ),
                ),
              ),
              const Text(
                'Use your Codex subscription for film chat. MCP connections are managed below.',
              ),
              if (_codex?.error != null) Text(_codex!.error!),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AiConnectionsScreen(),
                        ),
                      ),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Claude and Gemini AI connections'),
              ),
              const SizedBox(height: 20),
              Text(
                'Let assistants use Zanzibarr',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Local MCP access can read library titles and playback status. Source URLs, paths and provider credentials stay private.',
              ),
              SwitchListTile(
                title: const Text('Enable local MCP access'),
                subtitle: Text(
                  runtime.running
                      ? 'Listening on localhost'
                      : 'Disabled or unavailable',
                ),
                value: config?.enabled ?? false,
                onChanged: _busy || config == null
                    ? null
                    : (value) => _run(
                        () => runtime.save(config.copyWith(enabled: value)),
                      ),
              ),
              SwitchListTile(
                title: const Text('Allow indexer searches'),
                subtitle: const Text(
                  'Search requests use your indexer API quota.',
                ),
                value: config?.allowSearch ?? false,
                onChanged: _busy || config == null
                    ? null
                    : (value) => _run(
                        () => runtime.save(config.copyWith(allowSearch: value)),
                      ),
              ),
              SwitchListTile(
                title: const Text('Allow pause, resume and seek'),
                subtitle: const Text(
                  'Connected assistants can change active playback.',
                ),
                value: config?.allowPlayback ?? false,
                onChanged: _busy || config == null
                    ? null
                    : (value) => _run(
                        () =>
                            runtime.save(config.copyWith(allowPlayback: value)),
                      ),
              ),
              if (config != null) ...[
                Text('Endpoint: http://127.0.0.1:${config.port}/mcp'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _copy('http://127.0.0.1:${config.port}/mcp'),
                      child: const Text('Copy endpoint'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _copy(config.token),
                      child: const Text('Copy secret access token'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => runtime.save(
                                config.copyWith(token: newIntegrationToken()),
                              ),
                            ),
                      child: const Text('Revoke token and create a new one'),
                    ),
                  ],
                ),
                const Text(
                  'Use an HTTP MCP client such as Claude Code or Codex. Keep the token private. Access is limited to this computer and stops when Zanzibarr closes.',
                ),
              ],
              const Divider(height: 36),
              Text(
                'MCP connections and provider plugins',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Connect a trusted HTTPS MCP server, or a local HTTP server. Calls are explicit. Metadata plugins appear in title lookup; they receive your title queries and IMDb IDs.',
              ),
              for (final connection in config?.connections ?? <McpConnection>[])
                Card(
                  child: ListTile(
                    title: Text(connection.name),
                    subtitle: Text(
                      connection.metadata ? 'Metadata plugin' : 'MCP tools',
                    ),
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _McpToolsScreen(connection: connection),
                            ),
                          ),
                    trailing: IconButton(
                      tooltip: 'Edit connection',
                      icon: const Icon(Icons.edit),
                      onPressed: _busy ? null : () => _edit(connection),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed:
                    _busy || config == null || config.connections.length >= 20
                    ? null
                    : () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Add MCP connection or metadata plugin'),
              ),
              const Divider(height: 36),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FilmChatScreen(
                            runtime: runtime,
                            onFindReleases: (selection) async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SearchScreen(
                                    initialSelection: selection,
                                    autoSearchInitialSelection: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Discover films: chat and playlists'),
              ),
              Text(
                'Codex subscription account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Sign in through the official Codex app-server. Codex handles OAuth and stores credentials in the OS keyring in a separate Zanzibarr profile. Open Discover films to chat for recommendations and save playlists.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _executable,
                enabled: !_busy && _codex?.signingIn != true,
                decoration: const InputDecoration(
                  labelText: 'Official Codex executable path',
                  hintText: 'Full path to codex.exe',
                ),
                onChanged: (_) {
                  _codex?.dispose();
                  setState(() => _codex = null);
                },
              ),
              if (_codex?.error != null) Text(_codex!.error!),
              Text(
                _codex?.connected == true
                    ? 'Signed in with ChatGPT${_codex?.plan == null ? '' : ' (${_codex!.plan!})'}'
                    : _codex?.signingIn == true
                    ? 'Waiting for browser sign-in…'
                    : 'Not connected',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        _busy || config == null || _codex?.signingIn == true
                        ? null
                        : () => _run(_signIn),
                    child: const Text('Sign in with ChatGPT through Codex'),
                  ),
                  if (_codex?.signingIn == true)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(_codex!.cancelSignIn),
                      child: const Text('Cancel sign-in'),
                    ),
                  if (_codex?.connected == true)
                    TextButton(
                      onPressed: _busy ? null : () => _run(_codex!.signOut),
                      child: const Text(
                        'Sign out of Zanzibarr’s Codex profile',
                      ),
                    ),
                ],
              ),
              const Divider(height: 36),
              Text('Claude', style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'Use Claude and Gemini AI connections above to set up film chat with API access. Claude Code or Claude Desktop can also connect to the local MCP endpoint. Sign in to Claude subscriptions in their own app; no subscription tokens are imported into Zanzibarr.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(McpConnection? existing) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConnectionDialog(runtime: runtime, existing: existing),
  );
}

class _ConnectionDialog extends StatefulWidget {
  const _ConnectionDialog({required this.runtime, this.existing});
  final IntegrationRuntime runtime;
  final McpConnection? existing;
  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _url = TextEditingController(text: widget.existing?.url);
  late final _token = TextEditingController(text: widget.existing?.token);
  late bool _metadata = widget.existing?.metadata ?? false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final connection = McpConnection(
        id: widget.existing?.id ?? newIntegrationToken(),
        name: _name.text.trim(),
        url: _url.text.trim(),
        token: _token.text.trim(),
        metadata: _metadata,
      );
      if (!remove) McpConnection.fromJson(connection.toJson());
      final config = widget.runtime.settings!;
      final connections = [...config.connections];
      final index = connections.indexWhere((c) => c.id == connection.id);
      if (index >= 0) {
        if (remove) {
          connections.removeAt(index);
        } else {
          connections[index] = connection;
        }
      } else if (!remove) {
        connections.add(connection);
      }
      await widget.runtime.save(config.copyWith(connections: connections));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save. Use a name and HTTPS endpoint (HTTP only on localhost). Check storage, then retry; your draft is retained.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        widget.existing == null ? 'Add connection' : 'Edit connection',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _url,
                enabled: !_busy,
                maxLength: 2048,
                decoration: const InputDecoration(
                  labelText: 'MCP endpoint URL',
                ),
              ),
              TextField(
                controller: _token,
                enabled: !_busy,
                obscureText: true,
                maxLength: 8192,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Bearer token (optional)',
                ),
              ),
              CheckboxListTile(
                value: _metadata,
                title: const Text('Use as a metadata provider plugin'),
                subtitle: const Text(
                  'Server must provide metadata_search and metadata_details tools.',
                ),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _metadata = value ?? false),
              ),
              if (_error != null) Text(_error!),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _busy ? null : () => _save(remove: true),
            child: const Text('Remove connection'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _McpToolsScreen extends StatefulWidget {
  const _McpToolsScreen({required this.connection});
  final McpConnection connection;
  @override
  State<_McpToolsScreen> createState() => _McpToolsScreenState();
}

class _McpToolsScreenState extends State<_McpToolsScreen> {
  late final client = McpClient(widget.connection);
  final _arguments = TextEditingController(text: '{}');
  List<Map<String, dynamic>> _tools = [];
  String? _selected;
  String? _output;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _discover();
  }

  @override
  void dispose() {
    client.close();
    _arguments.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tools = await client.tools();
      if (mounted) {
        setState(() {
          _tools = tools;
          _selected = tools.firstOrNull?['name'] as String?;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not discover tools. Check the endpoint, token and server.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call() async {
    if (_busy || _selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _output = null;
    });
    try {
      final args = jsonDecode(_arguments.text);
      if (args is! Map<String, dynamic>) throw const FormatException();
      final result = await client.call(_selected!, args);
      if (mounted) {
        setState(
          () => _output = const JsonEncoder.withIndent('  ').convert(result),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tool call failed. Check the JSON arguments and connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.connection.name)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'External tool calls can share data or change the remote service. Review its description and arguments before running. Responses are untrusted provider content.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _busy ? null : _discover,
            child: const Text('Reconnect'),
          ),
        ],
        DropdownButtonFormField<String>(
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tool'),
          items: [
            for (final tool in _tools)
              DropdownMenuItem(
                value: tool['name'] as String,
                child: Text(tool['name'] as String),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _selected = value),
        ),
        if (_selected != null)
          SelectableText(
            const JsonEncoder.withIndent(
              '  ',
            ).convert(_tools.firstWhere((t) => t['name'] == _selected)),
          ),
        TextField(
          controller: _arguments,
          enabled: !_busy,
          minLines: 3,
          maxLines: 10,
          inputFormatters: [LengthLimitingTextInputFormatter(64000)],
          decoration: const InputDecoration(
            labelText: 'Arguments (JSON object)',
          ),
        ),
        FilledButton(
          onPressed: _busy || _selected == null ? null : _call,
          child: const Text('Run selected tool'),
        ),
        if (_output != null) SelectableText(_output!),
      ],
    ),
  );
}
