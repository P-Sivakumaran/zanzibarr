import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../integrations/codex_account.dart';
import '../integrations/integration_runtime.dart';
import '../integrations/integration_settings.dart';
import '../search/release_search_selection.dart';
import 'film_chat.dart';
import 'film_playlist.dart';
import 'ai_connections.dart';
import 'ai_connections_screen.dart';
import 'api_film_chat.dart';

class FilmChatScreen extends StatefulWidget {
  const FilmChatScreen({
    super.key,
    required this.onFindReleases,
    this.runtime,
    this.account,
    this.playlistStore,
    this.aiStore,
    this.apiChat,
  });
  final Future<void> Function(ReleaseSearchSelection) onFindReleases;
  final IntegrationRuntime? runtime;
  final CodexAccount? account;
  final FilmPlaylistStore? playlistStore;
  final AiConnectionStore? aiStore;
  final ApiFilmChat? apiChat;
  @override
  State<FilmChatScreen> createState() => _FilmChatScreenState();
}

class _FilmChatScreenState extends State<FilmChatScreen> {
  late final runtime = widget.runtime ?? IntegrationRuntime.instance;
  late final account = widget.account ?? CodexAccount();
  late final chat = FilmChat(account);
  late final store = widget.playlistStore ?? FilmPlaylistStore();
  late final aiStore = widget.aiStore ?? AiConnectionStore();
  late final apiChat = widget.apiChat ?? ApiFilmChat(aiStore);
  AiConnections _connections = const AiConnections();
  bool _aiReady = false;
  int _setupGeneration = 0;
  bool get _usesCodex => _connections.provider == FilmAiProvider.codex;
  final _prompt = TextEditingController();
  final _promptFocus = FocusNode();
  final _executable = TextEditingController();
  final _scroll = ScrollController();
  final _history = <FilmChatMessage>[];
  List<FilmPlaylist> _playlists = [];
  bool _connecting = false;
  bool _sending = false;
  bool _saving = false;
  bool _loaded = false;
  bool _finding = false;
  String? _error;
  String? _connectionError;
  bool _loadingPlaylists = false;
  bool _advancedOpen = false;
  String? _playlistError;

  @override
  void initState() {
    super.initState();
    account.addListener(_changed);
    unawaited(_setup());
    unawaited(_loadPlaylists());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _setup() async {
    final generation = ++_setupGeneration;
    try {
      final connections = await aiStore.load();
      if (!mounted || generation != _setupGeneration) return;
      setState(() {
        if (_connections.provider != connections.provider) _history.clear();
        _connections = connections;
        _aiReady = true;
        _connectionError = null;
      });
      if (!_usesCodex) {
        await account.disconnect();
        return;
      }
      await runtime.load();
      if (!mounted || generation != _setupGeneration) return;
      var path = runtime.settings?.codexExecutable ?? '';
      if (path.isEmpty) path = await CodexRpc.discoverExecutable() ?? '';
      if (!mounted || generation != _setupGeneration) return;
      _executable.text = path;
      // Reading account status does not start a browser or model request.
      if (path.isNotEmpty && !account.connected) await _connect(login: false);
    } catch (error) {
      if (mounted && generation == _setupGeneration) {
        setState(() => _connectionError = _message(error));
      }
    }
  }

  Future<void> _openAiConnections() async {
    if (_sending) return;
    ++_setupGeneration;
    setState(() {
      _aiReady = false;
      _connecting = false;
      _connectionError = null;
    });
    // Switching providers also cancels a pending local account check. Its late
    // completion must never open a sign-in browser over the settings screen.
    final disconnected = account.disconnect();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiConnectionsScreen(store: aiStore),
      ),
    );
    await disconnected;
    if (!mounted) return;
    await _setup();
  }

  Future<void> _stop() => _usesCodex ? chat.cancel() : apiChat.cancel();

  Future<void> _loadPlaylists() async {
    if (_loadingPlaylists) return;
    setState(() => _loadingPlaylists = true);
    try {
      final lists = await store.load();
      if (mounted) {
        setState(() {
          _playlists = lists;
          _loaded = true;
          _playlistError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _playlistError = _message(error));
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  String _message(Object error) => error is IntegrationException
      ? error.message
      : 'This action could not finish. Please try again.';

  bool get _providerConfigured => switch (_connections.provider) {
    FilmAiProvider.codex => account.connected,
    FilmAiProvider.claude => _connections.claudeKey.isNotEmpty,
    FilmAiProvider.gemini =>
      _connections.geminiAuthentication == GeminiAuthentication.apiKey
          ? _connections.geminiKey.isNotEmpty
          : _connections.googleTokens != null,
  };

  bool get _canSend =>
      _aiReady &&
      _providerConfigured &&
      !_sending &&
      !_connecting &&
      !account.signingIn &&
      _prompt.text.trim().isNotEmpty;

  Future<void> _connect({bool login = true, bool restart = false}) async {
    if (!_aiReady || !_usesCodex || _connecting || _sending) return;
    final generation = _setupGeneration;
    bool active() => mounted && generation == _setupGeneration;
    setState(() {
      _connecting = true;
      _connectionError = null;
    });
    try {
      if (restart) await account.disconnect();
      if (!active()) return;
      if (runtime.settings == null) await runtime.retry();
      if (!active()) return;
      final path = _executable.text.trim();
      if (path.isEmpty) {
        throw const IntegrationException(
          'Codex was not found. Install it, or choose its executable in Advanced connection settings.',
        );
      }
      if (runtime.settings!.codexExecutable != path) {
        await runtime.save(runtime.settings!.copyWith(codexExecutable: path));
      }
      if (!active()) return;
      await account.connect(path);
      if (!active() || account.connected || !login) return;
      final url = await account.signIn();
      if (!active()) return;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await account.cancelSignIn();
        throw const IntegrationException(
          'Could not open your browser. Try signing in again.',
        );
      }
    } catch (error) {
      if (active()) setState(() => _connectionError = _message(error));
    } finally {
      if (active()) setState(() => _connecting = false);
    }
  }

  void _usePrompt(String prompt) {
    _prompt.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    _promptFocus.requestFocus();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final reply = _usesCodex
          ? await chat.send(prompt, _history)
          : await apiChat.send(prompt, _history);
      if (!mounted) return;
      setState(() {
        _history.add(FilmChatMessage(prompt, reply));
        if (_history.length > 10) _history.removeAt(0);
        _prompt.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save(List<FilmPlaylist> next) async {
    if (_saving || !_loaded) {
      throw const IntegrationException(
        'Wait for playlists to finish loading or saving.',
      );
    }
    setState(() => _saving = true);
    try {
      await store.save(next, expected: _playlists);
      if (mounted) {
        setState(() {
          _playlists = next;
          _playlistError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _playlistError = _message(error));
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _playlistError = _message(error));
    }
  }

  Future<void> _namePlaylist({
    FilmPlaylist? existing,
    List<FilmSuggestion> films = const [],
  }) async {
    final controller = TextEditingController(
      text: existing?.name ?? 'Movie night',
    );
    String? error;
    var busy = false;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? 'Save playlist' : 'Rename playlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 100,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Playlist name'),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (error != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        await _loadPlaylists();
                        if (dialogContext.mounted) {
                          update(() => error = _playlistError);
                        }
                      },
                child: const Text('Reload saved lists'),
              ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final name = controller.text.trim();
                        if (name.isEmpty) {
                          throw const IntegrationException(
                            'Enter a playlist name.',
                          );
                        }
                        if (existing == null && _playlists.length >= 20) {
                          throw const IntegrationException(
                            'You can save up to 20 playlists. Remove one first.',
                          );
                        }
                        final current = existing == null
                            ? null
                            : _playlists
                                  .where((p) => p.id == existing.id)
                                  .firstOrNull;
                        if (existing != null && current == null) {
                          throw const IntegrationException(
                            'This playlist was removed elsewhere. Save your picks as a new playlist.',
                          );
                        }
                        final list =
                            current?.copyWith(name: name) ??
                            FilmPlaylist(
                              id: newIntegrationToken(),
                              name: name,
                              films: films,
                            );
                        await _save(
                          existing == null
                              ? [..._playlists, list]
                              : [
                                  for (final p in _playlists)
                                    if (p.id == existing.id) list else p,
                                ],
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (context.mounted) {
                          update(() {
                            busy = false;
                            error = _message(e);
                          });
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
  }

  Future<void> _add(List<FilmSuggestion> films) async {
    if (!_loaded || _saving) return;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to playlist'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('New playlist'),
          ),
          for (final p in _playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p.id),
              child: Text(p.name),
            ),
        ],
      ),
    );
    if (id == null || !mounted) return;
    if (id.isEmpty) {
      await _namePlaylist(films: films);
      return;
    }
    await _change(() async {
      final list = _playlists.firstWhere((p) => p.id == id);
      final seen = list.films.map((f) => f.identity).toSet();
      final updated = [
        ...list.films,
        ...films.where((f) => seen.add(f.identity)),
      ];
      if (updated.length > 100) {
        throw const IntegrationException(
          'A playlist can contain up to 100 films.',
        );
      }
      await _save([
        for (final p in _playlists)
          if (p.id == id) p.copyWith(films: updated) else p,
      ]);
    });
    if (mounted && _playlistError == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playlist saved')));
    }
  }

  Future<void> _editFilms(FilmPlaylist list, List<FilmSuggestion> films) =>
      _change(
        () => _save([
          for (final p in _playlists)
            if (p.id == list.id) p.copyWith(films: films) else p,
        ]),
      );
  Future<void> _find(FilmSuggestion film) async {
    if (_finding) return;
    setState(() => _finding = true);
    try {
      await widget.onFindReleases(film.selection);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(e))));
      }
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  void dispose() {
    account.removeListener(_changed);
    unawaited(chat.cancel());
    unawaited(apiChat.cancel());
    if (widget.account == null) account.dispose();
    _promptFocus.dispose();
    _prompt.dispose();
    _executable.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Discover films'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: const TabBar(
                tabs: [
                  Tab(text: 'Chat'),
                  Tab(text: 'Playlists'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(children: [_chatView(), _playlistView()]),
      ),
    ),
  );

  Widget _pageWidth(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: child,
    ),
  );

  Widget _chatView() => LayoutBuilder(
    builder: (context, constraints) {
      final inline =
          constraints.maxHeight < 520 ||
          MediaQuery.textScalerOf(context).scale(16) > 24;
      final contents = _chatContents();
      if (inline) {
        return SingleChildScrollView(
          key: const Key('chat-content-scroll'),
          controller: _scroll,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 20),
          child: _pageWidth(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...contents, const SizedBox(height: 24), _composer()],
            ),
          ),
        );
      }
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const Key('chat-content-scroll'),
              controller: _scroll,
              padding: const EdgeInsetsDirectional.fromSTEB(24, 28, 24, 24),
              child: _pageWidth(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: contents,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
            child: _pageWidth(_composer()),
          ),
        ],
      );
    },
  );

  List<Widget> _chatContents() => [
    if (_history.isEmpty) ...[
      Text(
        'Find your next great film',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'A mood, a genre, a film you loved. Start with an idea and make it a movie night.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
    ],
    _connectionCard(),
    const SizedBox(height: 24),
    if (_history.isEmpty) ...[
      Text('Try an idea', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      _promptIdeas(),
    ],
    for (final entry in _history) ...[
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            entry.prompt,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      const SizedBox(height: 20),
      SelectableText(
        entry.reply.message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
      const SizedBox(height: 12),
      for (final film in entry.reply.films)
        _filmCard(film, [
          TextButton.icon(
            onPressed: !_loaded || _saving ? null : () => _add([film]),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add to playlist'),
          ),
        ]),
      if (entry.reply.films.isNotEmpty)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: !_loaded || _saving
                ? null
                : () => _add(entry.reply.films),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Save these films as a playlist'),
          ),
        ),
      const SizedBox(height: 28),
    ],
    if (_playlistError != null) _playlistWarning(),
  ];

  String get _providerName =>
      _usesCodex ? 'ChatGPT' : _connections.provider.label;
  String? get _accountError =>
      _connectionError ?? (_usesCodex ? account.error : null);

  Widget _connectionCard() {
    final scheme = Theme.of(context).colorScheme;
    final failed = _accountError != null;
    final checking = _connecting || !_aiReady;
    final status = checking
        ? 'Checking connection…'
        : account.signingIn
        ? 'Waiting for browser sign-in'
        : failed
        ? 'Connection needs attention'
        : _providerConfigured
        ? (_usesCodex ? 'Connected' : 'Configured')
        : _usesCodex
        ? 'Not connected'
        : 'Setup needed';
    final icon = checking
        ? Icons.sync
        : failed
        ? Icons.error_outline
        : _providerConfigured
        ? Icons.check_circle_outline
        : Icons.link_off;
    return Card(
      key: const Key('chat-connection-card'),
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: failed ? scheme.error : scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _providerName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              status,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    if (_usesCodex && _aiReady)
                      IconButton(
                        key: const Key('chat-advanced-connection'),
                        tooltip: 'Advanced connection settings',
                        onPressed: () =>
                            setState(() => _advancedOpen = !_advancedOpen),
                        icon: Icon(
                          _advancedOpen ? Icons.expand_less : Icons.tune,
                        ),
                      ),
                    OutlinedButton.icon(
                      key: const Key('chat-ai-connections'),
                      onPressed: _sending ? null : _openAiConnections,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change provider'),
                    ),
                  ],
                ),
              ],
            ),
            if (checking) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                semanticsLabel: 'Checking AI connection',
              ),
              const SizedBox(height: 8),
              const Text(
                'You can write your request while we check, or choose another provider.',
              ),
            ] else if (account.signingIn) ...[
              const SizedBox(height: 14),
              const Text('Complete sign-in in your browser, then return here.'),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => _change(account.cancelSignIn),
                  child: const Text('Cancel sign-in'),
                ),
              ),
            ] else if (failed || !_providerConfigured) ...[
              const SizedBox(height: 14),
              Text(
                failed
                    ? 'We couldn’t connect to ChatGPT. Try again or choose another provider.'
                    : _usesCodex
                    ? 'Connect ChatGPT to get film recommendations. Your playlists work offline.'
                    : 'Add your credentials in AI connections to get film recommendations.',
              ),
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: _sending
                      ? null
                      : _usesCodex
                      ? () => _connect(restart: failed)
                      : _openAiConnections,
                  icon: Icon(failed ? Icons.refresh : Icons.login, size: 18),
                  label: Text(
                    failed
                        ? 'Retry connection'
                        : _usesCodex
                        ? 'Sign in with ChatGPT'
                        : 'Set up $_providerName',
                  ),
                ),
              ),
            ],
            if (_usesCodex && _aiReady && _advancedOpen) ...[
              const Divider(height: 32),
              Text(
                'Advanced connection settings',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Codex is detected automatically. Change the path only if needed.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _executable,
                enabled: !_connecting && !_sending && !account.signingIn,
                decoration: const InputDecoration(
                  labelText: 'Codex executable path',
                  hintText: 'Full path to codex.exe',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() => _connectionError = null);
                  unawaited(account.disconnect());
                },
              ),
              if (_accountError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(
                    _accountError!,
                    key: const Key('chat-connection-details'),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _connecting || _sending || account.signingIn
                        ? null
                        : () => _connect(login: false, restart: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Check connection'),
                  ),
                  if (account.connected)
                    TextButton(
                      onPressed: _sending || _connecting
                          ? null
                          : () async {
                              try {
                                await account.signOut();
                              } catch (e) {
                                if (mounted) {
                                  setState(
                                    () => _connectionError = _message(e),
                                  );
                                }
                              }
                            },
                      child: const Text('Sign out'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _promptIdeas() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720
          ? 3
          : constraints.maxWidth >= 480
          ? 2
          : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final idea in const [
            (
              Icons.local_movies_outlined,
              'Crime & mystery',
              'Slow-burn crime films from the 1970s',
            ),
            (
              Icons.wb_sunny_outlined,
              'Something uplifting',
              'A funny, uplifting movie night',
            ),
            (
              Icons.auto_awesome_outlined,
              'More like a favorite',
              'Films like Arrival, without spoilers',
            ),
          ])
            SizedBox(
              width: width,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _sending ? null : () => _usePrompt(idea.$3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(idea.$1, size: 22),
                    const SizedBox(height: 12),
                    Text(
                      idea.$2,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      idea.$3,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _composer() {
    final scheme = Theme.of(context).colorScheme;
    final target = _usesCodex
        ? 'OpenAI'
        : _connections.provider == FilmAiProvider.claude
        ? 'Anthropic'
        : 'Google';
    return ListenableBuilder(
      listenable: _promptFocus,
      builder: (context, _) => Container(
        key: const Key('chat-composer'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _promptFocus.hasFocus
                ? scheme.primary
                : scheme.outlineVariant,
            width: _promptFocus.hasFocus ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('chat-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Couldn’t finish this request',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      if (_usesCodex && !account.connected)
                        TextButton(
                          onPressed: _connecting
                              ? null
                              : () => _connect(restart: true),
                          child: const Text('Reconnect ChatGPT'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): () {
                  if (_canSend) unawaited(_send());
                },
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: true,
                ): () {
                  if (_canSend) unawaited(_send());
                },
              },
              child: TextField(
                key: const Key('chat-prompt'),
                controller: _prompt,
                focusNode: _promptFocus,
                enabled: !_sending,
                minLines: 2,
                maxLines: 4,
                maxLength: 4000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'What would you like to watch?',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _prompt,
              builder: (context, value, _) => Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IconButton(
                        onPressed: _aboutDiscovery,
                        tooltip: 'Privacy & AI information',
                        icon: const Icon(Icons.info_outline),
                      ),
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => setState(_history.clear),
                          child: const Text('New chat'),
                        ),
                      if (value.text.length >= 3600)
                        Text(
                          '${value.text.length}/4000',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  _sending
                      ? OutlinedButton.icon(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop'),
                        )
                      : FilledButton.icon(
                          key: const Key('chat-send'),
                          onPressed: _canSend ? _send : null,
                          icon: const Icon(Icons.arrow_upward, size: 20),
                          label: const Text('Send'),
                        ),
                ],
              ),
            ),
            if (_sending) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                semanticsLabel: 'Preparing film recommendations',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              !_aiReady
                  ? 'Loading your AI connection…'
                  : !_providerConfigured
                  ? 'You can write a request now. Connect your AI provider to send it.'
                  : 'Your prompt and recent chat go to $target when you send.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aboutDiscovery() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About film discovery'),
      content: const SingleChildScrollView(
        child: Text(
          'Your prompt and recent conversation go to your selected provider only when you send. '
          'ChatGPT uses your Codex subscription allowance; Claude and Gemini use API quota and may incur charges.\n\n'
          'Chat clears when you leave this screen. Playlists stay on this device and work offline. '
          'No indexer credentials, library or file paths are sent with your request.\n\n'
          'AI suggestions can be inaccurate. Use Find releases to check your indexers for availability. '
          'This interface currently uses English; the assistant can reply in your language.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  Widget _filmCard(FilmSuggestion film, List<Widget> actions) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            film.title + (film.year == null ? '' : ' (${film.year})'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            film.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            film.reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _finding ? null : () => _find(film),
                icon: const Icon(Icons.search),
                label: const Text('Find releases'),
              ),
              ...actions,
            ],
          ),
        ],
      ),
    ),
  );

  Widget _playlistWarning() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(_playlistError!, key: const Key('playlist-error')),
      ),
      TextButton.icon(
        onPressed: _loadingPlaylists || _saving ? null : _loadPlaylists,
        icon: const Icon(Icons.refresh),
        label: const Text('Reload playlists'),
      ),
    ],
  );

  Future<void> _deletePlaylist(FilmPlaylist list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'Delete “${list.name}” and its saved film list? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playlist'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _change(
        () => _save(_playlists.where((p) => p.id != list.id).toList()),
      );
    }
  }

  Widget _playlistView() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: _pageWidth(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your movie nights',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep your picks in order. Choose a release for each film when you’re ready to watch.',
          ),
          const SizedBox(height: 24),
          if (_playlistError != null) _playlistWarning(),
          if (_loadingPlaylists || _saving)
            const LinearProgressIndicator(semanticsLabel: 'Updating playlists'),
          if (_loaded && _playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_play_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A great movie night starts with a few ideas',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask for films in Chat, then save your favorites here.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) => OutlinedButton.icon(
                      onPressed: () =>
                          DefaultTabController.of(context).animateTo(0),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Explore film ideas'),
                    ),
                  ),
                ],
              ),
            ),
          for (final list in _playlists)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                key: ValueKey(list.id),
                title: Text(list.name),
                subtitle: Text('${list.films.length} films'),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _namePlaylist(existing: list),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Rename'),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : () => _deletePlaylist(list),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete playlist'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < list.films.length; i++)
                    _filmCard(list.films[i], [
                      IconButton(
                        tooltip: 'Move up',
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: _saving || i == 0
                            ? null
                            : () {
                                final films = [...list.films];
                                final film = films.removeAt(i);
                                films.insert(i - 1, film);
                                _editFilms(list, films);
                              },
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: _saving || i == list.films.length - 1
                            ? null
                            : () {
                                final films = [...list.films];
                                final film = films.removeAt(i);
                                films.insert(i + 1, film);
                                _editFilms(list, films);
                              },
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => _editFilms(
                                list,
                                [...list.films]..removeAt(i),
                              ),
                        child: const Text('Remove'),
                      ),
                    ]),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
