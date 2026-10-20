import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../metadata/artwork.dart';
import '../search/search_screen.dart';
import '../search/release_search_selection.dart';
import 'adult_catalog.dart';

class AdultLibraryScreen extends StatefulWidget {
  const AdultLibraryScreen({super.key, this.store, this.catalog});
  final AdultLibraryStore? store;
  final AdultCatalog? catalog;
  @override
  State<AdultLibraryScreen> createState() => _AdultLibraryScreenState();
}

class _AdultLibraryScreenState extends State<AdultLibraryScreen> {
  late final _store = widget.store ?? AdultLibraryStore.shared;
  late final _catalog = widget.catalog ?? AdultCatalog();
  final _query = TextEditingController();
  final _tpdb = TextEditingController();
  final _stash = TextEditingController();
  final _artwork = ArtworkLoader(validateUri: adultArtworkUri);
  List<AdultTitle> _saved = [], _results = [];
  AdultSource _source = AdultSource.tpdb;
  bool _enabled = false, _images = false, _movies = false;
  bool _loading = true, _busy = false, _dirty = false, _loadFailed = false;
  String? _error, _replacing;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    _tpdb.dispose();
    _stash.dispose();
    _artwork.close();
    if (widget.catalog == null) _catalog.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _store.storage.read('adult.settings.v1');
      final config = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
      final saved = await _store.load();
      if (!mounted) return;
      setState(() {
        _tpdb.text = config['tpdb'] as String? ?? '';
        _stash.text = config['stashdb'] as String? ?? '';
        _enabled = config['enabled'] == true;
        _images = config['images'] == true;
        _saved = saved;
        _loading = false;
        _loadFailed = false;
        _dirty = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _error =
              'Adult library could not be loaded. Retry before making changes.';
        });
      }
    }
  }

  void _fail(String text) {
    if (mounted) setState(() => _error = text);
  }

  Future<void> _saveSettings() async {
    setState(() => _busy = true);
    try {
      await _store.storage.write(
        'adult.settings.v1',
        jsonEncode({
          'enabled': _enabled,
          'images': _images,
          'tpdb': _tpdb.text.trim(),
          'stashdb': _stash.text.trim(),
        }),
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adult source settings saved.')),
      );
    } catch (_) {
      _fail('Settings could not be saved. Your changes are still here.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _results = [];
    });
    try {
      final rows = await _catalog.search(
        _source,
        _source == AdultSource.tpdb ? _tpdb.text : _stash.text,
        _query.text,
        movies: _movies,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _results = rows);
      if (rows.isEmpty) {
        _fail(
          'No matches returned. Try a title, studio or a more specific query.',
        );
      }
    } on AdultCatalogFailure catch (e) {
      if (generation == _generation) _fail(e.message);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<bool> _saveTitle(AdultTitle title) async {
    try {
      await _store.save(title, replacing: _replacing);
      final saved = await _store.load();
      if (!mounted) return false;
      setState(() {
        _saved = saved;
        _replacing = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match saved to adult library.')),
      );
      return true;
    } catch (_) {
      _fail(
        'This match could not be saved. The previous library is preserved.',
      );
      return false;
    }
  }

  void _releases([AdultTitle? title]) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SearchScreen(
        adultOnly: true,
        initialSelection: title == null
            ? null
            : ReleaseSearchSelection(title: title.title, kind: 'adult'),
      ),
    ),
  );
  Future<void> _detail(AdultTitle title) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title.kind == 'movie' ? 'Adult movie' : 'Adult scene'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                title.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              if (_images && title.artwork.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: 220,
                    height: 300,
                    child: TitleArtwork(
                      url: title.artwork,
                      title: title.title,
                      loader: _artwork,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                [
                  title.studio,
                  title.date,
                  title.source.label,
                ].where((v) => v.isNotEmpty).join(' | '),
              ),
              const SizedBox(height: 24),
              Text('Performers', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                title.performers.isEmpty
                    ? 'Not supplied by this source.'
                    : title.performers.join(', '),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final saved = await _saveTitle(title);
                      if (context.mounted) {
                        if (saved) {
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Match could not be saved. Please retry.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save match'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _releases(title),
                    icon: const Icon(Icons.search),
                    label: const Text('Find releases'),
                  ),
                  if (iafdReference(title.iafdUrl) case final uri?)
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          if (!await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          )) {
                            _fail('IAFD could not be opened.');
                          }
                        } catch (_) {
                          _fail('IAFD could not be opened.');
                        }
                      },
                      child: const Text('View IAFD reference'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Metadata is attributed to the selected catalog. Provider IDs are not IMDb IDs. Ratings and review counts are not inferred.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(AdultTitle title, {bool saved = false}) => Card(
    child: ListTile(
      leading: _images && title.artwork.isNotEmpty
          ? SizedBox(
              width: 48,
              height: 64,
              child: TitleArtwork(
                url: title.artwork,
                title: title.title,
                loader: _artwork,
              ),
            )
          : const Icon(Icons.video_library_outlined),
      title: Text(title.title),
      subtitle: Text(
        [
          title.studio,
          title.date,
          title.source.label,
        ].where((v) => v.isNotEmpty).join(' | '),
      ),
      onTap: () => _detail(title),
      trailing: saved
          ? PopupMenuButton<String>(
              tooltip: 'Manage saved match',
              onSelected: (action) async {
                if (action == 'rematch') {
                  setState(() {
                    _replacing = title.identity;
                    _query.text = title.title;
                    _source = title.source;
                    _movies = title.kind == 'movie';
                    _results = [];
                  });
                } else {
                  try {
                    await _store.remove(title.identity);
                    final rows = await _store.load();
                    if (mounted) setState(() => _saved = rows);
                  } catch (_) {
                    _fail('The saved title could not be removed.');
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rematch', child: Text('Rematch')),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from library'),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || !_dirty) return;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved source settings?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        setState(() => _dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Adult library & sources')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  ),
                if (_loadFailed)
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reload saved data'),
                  ),
                if (!_loadFailed) ...[
                  const Text(
                    'Separate catalog and library. English fallback. Source accounts and API access are required for metadata searches.',
                  ),
                  SwitchListTile(
                    title: const Text('Enable adult catalog'),
                    value: _enabled,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _enabled = v;
                            _dirty = true;
                            _results = [];
                            _generation++;
                          }),
                  ),
                  ExpansionTile(
                    title: const Text('Source connections'),
                    initiallyExpanded:
                        !_enabled ||
                        (_tpdb.text.isEmpty && _stash.text.isEmpty),
                    children: [
                      TextField(
                        controller: _tpdb,
                        obscureText: true,
                        enabled: !_busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'ThePornDB API token',
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      TextField(
                        controller: _stash,
                        obscureText: true,
                        enabled: !_busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'StashDB API key',
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'IAFD: provider-supplied references only. No direct IAFD API or scraping. A local Stash server uses a different API and is not connected here.',
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Show catalog artwork'),
                    subtitle: const Text(
                      'Loads supported ThePornDB images when this library is open. Off by default.',
                    ),
                    value: _images,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _images = v;
                            _dirty = true;
                            if (!v) _artwork.clear();
                          }),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton(
                      onPressed: _busy || !_dirty ? null : _saveSettings,
                      child: const Text('Save source settings'),
                    ),
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _busy || _dirty ? null : () => _releases(),
                      icon: const Icon(Icons.search),
                      label: const Text('Search adult NZB releases'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AdultSource>(
                      initialValue: _source,
                      key: ValueKey(_source),
                      decoration: const InputDecoration(
                        labelText: 'Metadata source',
                      ),
                      items: [
                        for (final s in AdultSource.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: _busy
                          ? null
                          : (s) {
                              if (s != null) {
                                setState(() {
                                  _source = s;
                                  _movies = false;
                                  _results = [];
                                });
                              }
                            },
                    ),
                    if (_source == AdultSource.tpdb)
                      SwitchListTile(
                        title: const Text('Search movies instead of scenes'),
                        value: _movies,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _movies = v;
                                _results = [];
                              }),
                      ),
                    TextField(
                      controller: _query,
                      enabled: !_busy,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Search catalog',
                      ),
                      onSubmitted: (_) {
                        if (!_busy && !_dirty) _search();
                      },
                    ),
                    FilledButton(
                      onPressed: _busy || _dirty ? null : _search,
                      child: Text(_busy ? 'Working...' : 'Search metadata'),
                    ),
                    if (_replacing != null)
                      ListTile(
                        title: const Text(
                          'Choose a replacement match. The saved title stays until you save a new match.',
                        ),
                        trailing: TextButton(
                          onPressed: () => setState(() => _replacing = null),
                          child: const Text('Cancel rematch'),
                        ),
                      ),
                    for (final title in _results) _tile(title),
                    const SizedBox(height: 24),
                    Text(
                      'Saved adult titles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_saved.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Save a catalog match to keep it across restarts.',
                        ),
                      ),
                    for (final title in _saved) _tile(title, saved: true),
                  ],
                ],
              ],
            ),
    ),
  );
}
