import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../integrations/integration_settings.dart';
import '../metadata/metadata_enrichment.dart';

class EnrichmentSettingsScreen extends StatefulWidget {
  const EnrichmentSettingsScreen({super.key, this.store, this.integrations});
  final EnrichmentSettingsStore? store;
  final IntegrationStore? integrations;
  @override
  State<EnrichmentSettingsScreen> createState() =>
      _EnrichmentSettingsScreenState();
}

class _EnrichmentSettingsScreenState extends State<EnrichmentSettingsScreen> {
  late final _store = widget.store ?? EnrichmentSettingsStore();
  final _token = TextEditingController();
  bool _locations = false, _ready = false, _busy = false;
  String _reviewId = '';
  List<McpConnection> _connections = [];
  String? _message;
  EnrichmentSettings? _saved;
  bool _allowPop = false, _confirming = false;
  bool get _dirty =>
      _saved != null &&
      (_token.text.trim() != _saved!.tmdbToken ||
          _locations != _saved!.locations ||
          _reviewId != _saved!.reviewConnectionId);
  void _changed() {
    if (_ready && mounted) setState(() {});
  }

  Future<void> _leave() async {
    if (_busy || _confirming) return;
    if (_dirty) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard metadata changes?'),
          content: const Text(
            'Your saved sources stay unchanged until you save.',
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
      _confirming = false;
      if (discard != true || !mounted) return;
    }
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _token.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await _store.load();
      final integrations = await (widget.integrations ?? IntegrationStore())
          .load();
      if (!mounted) return;
      setState(() {
        _token.text = config.tmdbToken;
        _locations = config.locations;
        _reviewId = config.reviewConnectionId;
        _connections = integrations.connections
            .where((c) => c.metadata)
            .toList();
        _ready = true;
        _saved = config;
        _message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Additional metadata settings could not be loaded. Retry to preserve saved choices.',
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final draft = EnrichmentSettings(
      tmdbToken: _token.text.trim(),
      locations: _locations,
      reviewConnectionId: _reviewId,
    );
    try {
      await _store.save(draft);
      if (mounted) {
        setState(() {
          _saved = draft;
          _message =
              'Additional metadata settings saved. Open a title to load details.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Settings could not be saved. Check the token; your draft is kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _source() async {
    try {
      if (await launchUrl(
        Uri.https('www.themoviedb.org', '/settings/api'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The provider website could not be opened.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _token.removeListener(_changed);
    _token.clear();
    _token.dispose();
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
        title: const Text('Cast, topics & review context'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _leave,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Optional sources enrich identified titles. Playback and ordinary OMDb lookups keep working without them.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Cast & topics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  enabled: _ready && !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 2048,
                  decoration: const InputDecoration(
                    labelText: 'TMDB API Read Access Token',
                    helperText:
                        'Use the read access token, not the shorter API key. Clear and save to disconnect.',
                    helperMaxLines: 3,
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                TextButton(
                  onPressed: _source,
                  child: const Text('Get a TMDB read access token'),
                ),
                const Text(
                  'Adds cast, character names, portraits and topic keywords. Image loading follows your artwork preference.',
                ),
                const SizedBox(height: 24),
                Text('Places', style: Theme.of(context).textTheme.titleLarge),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Look up filming locations on Wikidata'),
                  subtitle: const Text(
                    'Sends the identified IMDb title ID to Wikidata. Filming locations and story settings are shown separately. Coverage varies.',
                  ),
                  value: _locations,
                  onChanged: _ready && !_busy
                      ? (v) => setState(() => _locations = v)
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Review counts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_reviewId),
                  initialValue: _reviewId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Additional review provider',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    for (final c in _connections)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    if (_reviewId.isNotEmpty &&
                        !_connections.any((c) => c.id == _reviewId))
                      DropdownMenuItem(
                        value: _reviewId,
                        child: const Text(
                          'Previously selected provider (unavailable)',
                        ),
                      ),
                  ],
                  onChanged: _ready && !_busy
                      ? (id) => setState(() => _reviewId = id ?? '')
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose a metadata connection configured in MCP & plugins. It must supply each score with its verified review or vote count. Missing counts remain unavailable. Critic totals are distinct from audience votes; no count is estimated from a score.',
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    onPressed: _ready && !_busy ? _save : null,
                    child: Text(
                      _busy ? 'Saving...' : 'Save additional sources',
                    ),
                  ),
                ),
                if (!_ready && _message == null)
                  const LinearProgressIndicator(),
                if (_message != null)
                  Semantics(liveRegion: true, child: Text(_message!)),
                if (!_ready && _message != null)
                  TextButton(onPressed: _load, child: const Text('Retry')),
                const SizedBox(height: 24),
                const Text('TMDB credits'),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Image.asset(
                      'assets/branding/tmdb.png',
                      width: 90,
                      semanticLabel: 'TMDB logo',
                    ),
                  ),
                ),
                const Text(
                  'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
