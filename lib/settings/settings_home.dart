import 'package:flutter/material.dart';
import '../chat/ai_connections_screen.dart';
import '../integrations/integrations_screen.dart';
import '../metadata/artwork.dart';
import '../metadata/metadata_service.dart';
import '../ui/app_background.dart';
import 'indexer_settings.dart';
import 'provider_settings.dart';
import 'settings_screen.dart';
import 'ui_preferences.dart';
import 'language_settings.dart';
import 'enrichment_settings.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({
    super.key,
    this.uiPreferences,
    this.providerStore,
    this.indexerStore,
    this.onCheckForUpdates,
  });
  final UiPreferencesController? uiPreferences;
  final ProviderSettingsStore? providerStore;
  final IndexerSettingsStore? indexerStore;
  final Future<void> Function()? onCheckForUpdates;
  @override
  State<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends State<SettingsHomeScreen> {
  bool _checking = false;
  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  Future<void> _update() async {
    setState(() => _checking = true);
    try {
      await widget.onCheckForUpdates?.call();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _item(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool autofocus = false,
  }) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      autofocus: autofocus,
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: AppBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Preferences & connections',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Personalize viewing and manage your services.'),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width =
                        constraints.maxWidth >= 800 &&
                            MediaQuery.textScalerOf(context).scale(16) < 26
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    final items = <Widget>[
                      _item(
                        Icons.palette_outlined,
                        'Appearance',
                        'Light or dark theme',
                        () => _open(
                          AppearanceSettingsScreen(
                            preferences: widget.uiPreferences,
                          ),
                        ),
                        autofocus: true,
                      ),
                      _item(
                        Icons.translate,
                        'Language & subtitles',
                        'App, audio and subtitle preferences',
                        () => _open(
                          LanguageSettingsScreen(
                            uiPreferences: widget.uiPreferences,
                          ),
                        ),
                      ),
                      _item(
                        Icons.image_outlined,
                        'Artwork & ratings',
                        'Posters, OMDb and critic score sources',
                        () => _open(const MetadataPreferencesScreen()),
                      ),
                      _item(
                        Icons.auto_awesome,
                        'AI connections',
                        'ChatGPT, Claude and Gemini for film & TV chat',
                        () => _open(const AiConnectionsScreen()),
                      ),
                      _item(
                        Icons.dns_outlined,
                        'Usenet provider',
                        'Server, account and connection limits',
                        () => _open(
                          SettingsScreen(
                            store: widget.providerStore,
                            indexerStore: widget.indexerStore,
                            initialSection: SettingsSection.provider,
                          ),
                        ),
                      ),
                      _item(
                        Icons.travel_explore,
                        'Indexers',
                        'Search sources and API keys',
                        () => _open(
                          SettingsScreen(
                            store: widget.providerStore,
                            indexerStore: widget.indexerStore,
                            initialSection: SettingsSection.indexer,
                          ),
                        ),
                      ),
                      _item(
                        Icons.extension_outlined,
                        'MCP & plugins',
                        'Optional assistant access and metadata providers',
                        () => _open(const IntegrationsScreen()),
                      ),
                    ];
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final item in items)
                          SizedBox(width: width, child: item),
                      ],
                    );
                  },
                ),
                if (widget.onCheckForUpdates != null) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _update,
                      icon: const Icon(Icons.system_update_alt),
                      label: Text(
                        _checking
                            ? 'Checking for updates...'
                            : 'Check for updates',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Some settings use English fallback. Credentials stay in your device secure storage.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key, this.preferences});
  final UiPreferencesController? preferences;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Appearance')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: preferences == null
              ? const Text('Appearance settings are unavailable in this view.')
              : ListenableBuilder(
                  listenable: preferences!,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Theme',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ThemeMode>(
                        key: ValueKey(preferences!.themeMode),
                        initialValue: preferences!.themeMode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Appearance',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                        ],
                        onChanged: (mode) async {
                          if (mode == null) return;
                          try {
                            await preferences!.setThemeMode(mode);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Appearance could not be saved.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}

class MetadataPreferencesScreen extends StatefulWidget {
  const MetadataPreferencesScreen({super.key, this.store});
  final MetadataSettingsStore? store;
  @override
  State<MetadataPreferencesScreen> createState() =>
      _MetadataPreferencesScreenState();
}

class _MetadataPreferencesScreenState extends State<MetadataPreferencesScreen> {
  late final _store = widget.store ?? MetadataSettingsStore();
  final _key = TextEditingController();
  bool _loaded = false, _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final key = await _store.load();
      if (mounted) {
        setState(() {
          _key.text = key;
          _loaded = true;
          _message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Metadata settings could not be loaded.');
      }
    }
  }

  Future<void> _save() async {
    if (_key.text.trim().isNotEmpty && !isValidMetadataApiKey(_key.text)) {
      setState(() => _message = 'Enter a valid OMDb API key.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _store.save(_key.text);
      if (mounted) setState(() => _message = 'Metadata settings saved.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Metadata settings could not be saved. Your draft is kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Artwork & ratings')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Posters', style: Theme.of(context).textTheme.titleLarge),
              const ArtworkSettings(),
              const SizedBox(height: 24),
              Text(
                'Title details & critic scores',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Optional OMDb lookups supply title artwork, synopsis and available IMDb, Rotten Tomatoes and Metacritic scores. Missing scores stay unavailable. Titles are identified automatically when metadata access is configured. Rematch can correct a result.',
              ),
              const SizedBox(height: 16),
              if (!_loaded && _message == null) const LinearProgressIndicator(),
              TextField(
                controller: _key,
                enabled: _loaded && !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 128,
                decoration: const InputDecoration(
                  labelText: 'OMDb API key',
                  helperText: 'Clear and save to remove this key.',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  onPressed: _loaded && !_busy ? _save : null,
                  child: const Text('Save metadata settings'),
                ),
              ),
              if (_message != null)
                Semantics(liveRegion: true, child: Text(_message!)),
              if (!_loaded && _message != null)
                TextButton(onPressed: _load, child: const Text('Retry')),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EnrichmentSettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.people_outline),
                label: const Text('Cast, topics & review context'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ratings retain their provider attribution. OMDb scores do not provide a verified Rotten Tomatoes review URL.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
