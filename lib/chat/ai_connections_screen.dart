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
            'Saved. Return to Discover films to chat with ${config.provider.label}.';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI connections')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose the assistant for film recommendations. API access uses your provider account and quota; it does not use Claude or Gemini chat subscriptions. Setup text currently uses English.',
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
                decoration: const InputDecoration(
                  labelText: 'Film chat provider',
                ),
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
                  'Save this choice, then use Connection setup in Discover films to sign in with ChatGPT through the installed Codex executable.',
                ),
              if (_provider == FilmAiProvider.claude) ...[
                const Text(
                  'Use a Claude Console API key. It is saved in OS secure storage and sent only to Anthropic when you press Send. Claude subscription OAuth is not used.',
                ),
                _field('Claude API key', _claudeKey, secret: true),
                _field('Claude model ID', _claudeModel),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            _link('https://platform.claude.com/settings/keys'),
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
                _field('Gemini model ID', _geminiModel),
                if (_auth == GeminiAuthentication.apiKey) ...[
                  _field('Gemini API key', _geminiKey, secret: true),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _link('https://aistudio.google.com/apikey'),
                    child: const Text('Get a Gemini API key'),
                  ),
                ] else ...[
                  const Text(
                    'Register a Desktop app OAuth client in your Google Cloud project, enable the Generative Language API and add yourself as a test user. Google consent requests Cloud API access. Tokens stay in OS secure storage. Browser sign-in currently supports Windows, macOS and Linux.',
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
                          child: const Text('Disconnect Google on this device'),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const Key('save-ai-connections'),
                  onPressed: _busy ? null : () => _run(() => _save(_draft)),
                  child: const Text('Save and use this provider'),
                ),
              ),
              if (_status != null)
                Text(_status!, key: const Key('ai-connection-status')),
              const SizedBox(height: 12),
              const Text(
                'Saving does not send a prompt or verify model access. Clear an API key and save to remove it. Changing provider starts a new chat; saved playlists remain available.',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
