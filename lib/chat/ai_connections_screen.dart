import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../integrations/integration_settings.dart';
import 'ai_connections.dart';
import 'google_oauth.dart';

Future<bool> openAiConnectionLink(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class AiConnectionsScreen extends StatefulWidget {
  const AiConnectionsScreen({
    super.key,
    this.store,
    this.google,
    this.openLink = openAiConnectionLink,
  });
  final AiConnectionStore? store;
  final GoogleOAuth? google;
  final Future<bool> Function(Uri) openLink;
  @override
  State<AiConnectionsScreen> createState() => _AiConnectionsScreenState();
}

class _AiConnectionsScreenState extends State<AiConnectionsScreen> {
  late final _store = widget.store ?? AiConnectionStore();
  late final _google = widget.google ?? GoogleOAuth();
  final _claudeKey = TextEditingController();
  final _claudeModel = TextEditingController();
  final _geminiKey = TextEditingController();
  final _geminiModel = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _project = TextEditingController();
  AiConnections? _saved;
  FilmAiProvider _provider = FilmAiProvider.codex;
  GeminiAuthentication _auth = GeminiAuthentication.apiKey;
  bool _allowPop = false;
  bool _confirmingLeave = false;
  bool _busy = false;
  bool _signingIn = false;
  String? _error, _status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _run(() async {
    final config = await _store.load();
    if (!mounted) return;
    _saved = config;
    _provider = config.provider;
    _auth = config.geminiAuthentication;
    _claudeKey.text = config.claudeKey;
    _claudeModel.text = config.claudeModel;
    _geminiKey.text = config.geminiKey;
    _geminiModel.text = config.geminiModel;
    _clientId.text = config.googleClientId;
    _clientSecret.text = config.googleClientSecret;
    _project.text = config.googleProject;
  });

  AiConnections get _draft => _saved!.copyWith(
    provider: _provider,
    geminiAuthentication: _auth,
    claudeKey: _claudeKey.text.trim(),
    claudeModel: _claudeModel.text.trim(),
    geminiKey: _geminiKey.text.trim(),
    geminiModel: _geminiModel.text.trim(),
    googleClientId: _clientId.text.trim(),
    googleClientSecret: _clientSecret.text.trim(),
    googleProject: _project.text.trim(),
  );

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is IntegrationException
              ? error.message
              : 'Connection setup could not finish. Please retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _signingIn = false;
        });
      }
    }
  }

  Future<void> _save(AiConnections config) async {
    await _store.save(config);
    if (mounted) {
      setState(() {
        _saved = config;
        _status =
            'Saved. Return to Discover films & TV to chat with ${config.provider.label}.';
      });
    }
  }

  Future<void> _signIn() => _run(() async {
    final draft = _draft;
    draft.validateGoogleClient();
    setState(() => _signingIn = true);
    final tokens = await _google.signIn(draft, widget.openLink);
    if (!mounted) return;
    await _save(draft.copyWith(googleTokens: tokens));
  });

  Future<void> _link(String url) => _run(() async {
    if (!await widget.openLink(Uri.parse(url))) {
      throw const IntegrationException(
        'Could not open the browser. Please retry.',
      );
    }
  });

  bool get _dirty =>
      _saved != null &&
      jsonEncode(_draft.toJson()) != jsonEncode(_saved!.toJson());
  Future<void> _leave() async {
    if (_confirmingLeave || _busy) return;
    if (!_dirty) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
      return;
    }
    _confirmingLeave = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard connection changes?'),
        content: const Text(
          'Your saved connection stays unchanged until you save.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  Widget _advancedModel(String label, TextEditingController controller) =>
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Advanced model settings'),
        subtitle: const Text('Use a specific model ID'),
        children: [_field(label, controller)],
      );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool secret = false,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      enabled: !_busy && _saved != null,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: secret ? 8192 : 200,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 5,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() => _status = null),
    ),
  );

  @override
  void dispose() {
    _google.cancel();
    for (final controller in [
      _claudeKey,
      _claudeModel,
      _geminiKey,
      _geminiModel,
      _clientId,
      _clientSecret,
      _project,
    ]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('AI connections'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _leave,
        ),
      ),
      bottomNavigationBar: _saved == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Center(
                  heightFactor: 1,
                  child: SizedBox(
                    width: 920,
                    child: FilledButton(
                      key: const Key('save-ai-connections'),
                      onPressed: _busy ? null : () => _run(() => _save(_draft)),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Save and use this provider'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Film & TV assistant',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a provider, add its connection details, then save.',
              ),
              if (_saved != null)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text('Saved provider: ${_saved!.provider.label}'),
                    subtitle: const Text(
                      'Saving settings does not send a prompt or verify access.',
                    ),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, key: const Key('ai-connection-error')),
              if (_saved == null && !_busy)
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry loading connections'),
                ),
              if (_saved != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<FilmAiProvider>(
                  key: const Key('ai-provider'),
                  initialValue: _provider,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chat provider'),
                  items: [
                    for (final p in FilmAiProvider.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _provider = value!;
                          _status = null;
                        }),
                ),
                const SizedBox(height: 16),
                if (_provider == FilmAiProvider.codex)
                  const Text(
                    '1. Save ChatGPT as your provider.\n2. Open film & TV chat and choose Sign in with ChatGPT.\n3. Complete sign-in in your browser.',
                  ),
                if (_provider == FilmAiProvider.claude) ...[
                  const Text(
                    'Connect with your Claude Console API key. API usage is billed through your Anthropic account.',
                  ),
                  _field('Claude API key', _claudeKey, secret: true),
                  _advancedModel('Claude model ID', _claudeModel),
                  TextButton(
                    style: TextButton.styleFrom(
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _link(
                            'https://platform.claude.com/settings/keys',
                          ),
                    child: const Text('Open Claude Console'),
                  ),
                ],
                if (_provider == FilmAiProvider.gemini) ...[
                  DropdownButtonFormField<GeminiAuthentication>(
                    key: const Key('gemini-auth'),
                    initialValue: _auth,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Gemini authentication',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: GeminiAuthentication.apiKey,
                        child: Text('API key'),
                      ),
                      DropdownMenuItem(
                        value: GeminiAuthentication.google,
                        child: Text('Google sign-in (OAuth)'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _auth = value!;
                            _status = null;
                          }),
                  ),
                  _advancedModel('Gemini model ID', _geminiModel),
                  if (_auth == GeminiAuthentication.apiKey) ...[
                    _field('Gemini API key', _geminiKey, secret: true),
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      onPressed: _busy
                          ? null
                          : () => _link('https://aistudio.google.com/apikey'),
                      child: const Text('Get a Gemini API key'),
                    ),
                  ] else ...[
                    const Text(
                      'Use a registered Google Desktop OAuth client. Complete the project details below, then sign in with Google. Browser sign-in supports Windows, macOS and Linux.',
                    ),
                    _field('Google Cloud project ID', _project),
                    _field('Google OAuth client ID', _clientId),
                    _field(
                      'Google OAuth client secret',
                      _clientSecret,
                      secret: true,
                      helper:
                          'Enter the desktop client secret if Google supplied one.',
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      onPressed: _busy
                          ? null
                          : () => _link(
                              'https://ai.google.dev/gemini-api/docs/oauth',
                            ),
                      child: const Text('Google OAuth setup instructions'),
                    ),
                    Text(
                      _draft.googleTokens == null
                          ? 'Google is not connected for these client details.'
                          : 'Google sign-in is saved on this device.',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _busy ||
                                  !(Platform.isWindows ||
                                      Platform.isLinux ||
                                      Platform.isMacOS)
                              ? null
                              : _signIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                        ),
                        if (_signingIn)
                          TextButton(
                            onPressed: _google.cancel,
                            child: const Text('Cancel Google sign-in'),
                          ),
                        if (_saved!.googleTokens != null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => _save(
                                      _draft.copyWith(clearGoogleTokens: true),
                                    ),
                                  ),
                            child: const Text(
                              'Disconnect Google on this device',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (_status != null)
                  Text(_status!, key: const Key('ai-connection-status')),
                const SizedBox(height: 12),
                const ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Privacy & account details'),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Keys and tokens stay in OS secure storage. API access uses provider quota, separate from Claude or Gemini chat subscriptions. Clear a key and save to remove it. Changing provider starts a new chat; playlists remain available. Setup text uses English fallback.',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
