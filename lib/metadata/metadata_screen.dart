import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../player/watchlist.dart';
import '../search/release_search_selection.dart';
import '../search/structured_search_dialog.dart';
import '../tv_focus.dart';
import 'metadata_service.dart';
import 'title_details_screen.dart';
import 'library_screen.dart';
import 'artwork.dart';

Future<void> _openLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Platform errors can include URLs; expose only the static explanation.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).metadataLinkFailed)),
    );
  }
}

class MetadataScreen extends StatefulWidget {
  const MetadataScreen({
    super.key,
    required this.service,
    required this.store,
    this.watchlistStore,
    this.initialQuery = '',
    this.initialKind = 'movie',
    this.providerName,
    this.requiresApiKey = true,
    this.selectTitleOnly = false,
  });
  final MetadataService service;
  final MetadataSettingsStore store;
  final WatchlistStore? watchlistStore;
  final String initialQuery;
  final String initialKind;
  final String? providerName;
  final bool requiresApiKey;
  final bool selectTitleOnly;
  @override
  State<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends State<MetadataScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late final _queryFocus = dpadTraversalFocusNode(_query);
  String _key = '';
  bool get _lookupReady => !widget.requiresApiKey || _key.isNotEmpty;
  bool _loadingKey = true;
  bool _keyError = false;
  bool _busy = false;
  String? _error;
  List<MediaTitle>? _titles;
  String _kind = 'movie';
  String _activeQuery = '';
  String _activeKind = 'movie';
  int _page = 1;
  bool _hasMore = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'tv' || widget.initialKind == 'series'
        ? 'series'
        : 'movie';
    _loadKey();
  }

  @override
  void dispose() {
    ++_generation;
    _queryFocus.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    if (!widget.requiresApiKey) {
      setState(() => _loadingKey = false);
      return;
    }
    setState(() => _loadingKey = true);
    try {
      final key = await widget.store.load();
      if (!mounted) return;
      setState(() {
        _key = key;
        _keyError = false;
        _loadingKey = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _keyError = true;
          _loadingKey = false;
        });
      }
    }
  }

  Future<void> _configure() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MetadataKeyDialog(
        store: widget.store,
        service: widget.service,
        initialKey: _key,
      ),
    );
    if (changed == true && mounted) {
      ++_generation;
      widget.service.clearCache();
      setState(() {
        _titles = null;
        _busy = false;
        _error = null;
        _hasMore = false;
      });
      await _loadKey();
    }
  }

  void _invalidate() {
    ++_generation;
    setState(() {
      _titles = null;
      _hasMore = false;
      _busy = false;
      _error = null;
    });
  }

  Future<void> _search({bool more = false}) async {
    if (_busy || _loadingKey || _keyError || !_lookupReady) return;
    final query = more ? _activeQuery : _query.text.trim();
    if (query.isEmpty) return;
    final kind = more ? _activeKind : _kind;
    final next = more ? _page + 1 : 1;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _titles = null;
        _activeQuery = query;
        _activeKind = kind;
        _hasMore = false;
      }
    });
    try {
      final page = await widget.service.search(
        _key,
        query,
        kind: kind,
        page: next,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = <String>{};
        _titles = [
          for (final title in [...?(more ? _titles : null), ...page.titles])
            if (seen.add(title.imdbId)) title,
        ];
        _page = next;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = error is MetadataException ? error.code : 'network',
      );
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _choose(MediaTitle title) async {
    if (widget.selectTitleOnly) {
      Navigator.pop(context, title);
      return;
    }
    final selected = await Navigator.of(context).push<ReleaseSearchSelection>(
      MaterialPageRoute(
        builder: (_) => TitleDetailsScreen(
          title: title,
          service: widget.service,
          apiKey: _key,
          providerName: widget.providerName,
          watchlistStore: widget.watchlistStore ?? WatchlistStore(),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final selection = await showStructuredSearchDialog(
      context,
      initial: selected,
    );
    if (selection != null && mounted) Navigator.pop(context, selection);
  }

  Future<void> _manual() async {
    if (widget.selectTitleOnly) return;
    final selection = await showStructuredSearchDialog(
      context,
      initial: ReleaseSearchSelection(
        title: _query.text.trim(),
        kind: _kind == 'series' ? 'tv' : 'movie',
      ),
    );
    if (selection != null && mounted) Navigator.pop(context, selection);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final titles = _titles;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectTitleOnly
              ? 'Match saved release'
              : l.metadataBrowseTitle,
        ),
        actions: [
          if (widget.requiresApiKey)
            IconButton(
              tooltip: l.metadataConfigure,
              onPressed: _loadingKey || _keyError ? null : _configure,
              icon: const Icon(Icons.key_rounded),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        widget.providerName == null
                            ? l.metadataPrivacyHint
                            : 'Queries and title IDs are sent to ${widget.providerName!}. Ratings are provided by this plugin.',
                      ),
                      const SizedBox(height: 8),
                      const Text('New library copy uses English fallback.'),
                      const ArtworkSettings(),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _query,
                        focusNode: _queryFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        onChanged: (_) => _invalidate(),
                        decoration: InputDecoration(
                          labelText: l.metadataQueryHint,
                          suffixIcon: IconButton(
                            tooltip: l.searchTooltip,
                            onPressed: _busy || !_lookupReady ? null : _search,
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            label: Text(l.metadataMovie),
                            selected: _kind == 'movie',
                            onSelected: (_) {
                              _invalidate();
                              setState(() => _kind = 'movie');
                            },
                          ),
                          ChoiceChip(
                            label: Text(l.metadataSeries),
                            selected: _kind == 'series',
                            onSelected: (_) {
                              _invalidate();
                              setState(() => _kind = 'series');
                            },
                          ),
                          if (!widget.selectTitleOnly)
                            TextButton.icon(
                              onPressed: _manual,
                              icon: const Icon(Icons.tune_rounded),
                              label: Text(l.structuredSearchTitle),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_loadingKey) const LinearProgressIndicator(),
                if (_keyError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(l.settingsLoadHint),
                        TextButton(onPressed: _loadKey, child: Text(l.retry)),
                      ],
                    ),
                  ),
                if (!_loadingKey && !_keyError && !_lookupReady)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(l.metadataKeyHint),
                        FilledButton(
                          onPressed: _configure,
                          child: Text(l.metadataConfigure),
                        ),
                      ],
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _error == 'key'
                              ? l.metadataKeyFailed
                              : _error == 'limit'
                              ? l.metadataLimit
                              : l.metadataFailed,
                        ),
                        TextButton(
                          onPressed: () =>
                              _search(more: titles != null && _hasMore),
                          child: Text(l.retry),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (titles != null && titles.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(l.searchNoResults)),
              ),
            ),
          if (titles != null && titles.isNotEmpty)
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    (constraints.crossAxisExtent /
                            MediaQuery.textScalerOf(context).scale(190))
                        .floor()
                        .clamp(1, 5);
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: (titles.length / columns).ceil(),
                    itemBuilder: (context, row) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var col = 0; col < columns; col++) ...[
                            if (col > 0) const SizedBox(width: 16),
                            Expanded(
                              child: row * columns + col < titles.length
                                  ? TitleCard(
                                      title: titles[row * columns + col],
                                      onOpen: () =>
                                          _choose(titles[row * columns + col]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _search(more: true),
                  child: Text(l.loadMore),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetadataKeyDialog extends StatefulWidget {
  const _MetadataKeyDialog({
    required this.store,
    required this.service,
    required this.initialKey,
  });
  final MetadataSettingsStore store;
  final MetadataService service;
  final String initialKey;
  @override
  State<_MetadataKeyDialog> createState() => _MetadataKeyDialogState();
}

class _MetadataKeyDialogState extends State<_MetadataKeyDialog> {
  late final _controller = TextEditingController(text: widget.initialKey);
  late final _focus = dpadTraversalFocusNode(_controller);
  bool _saving = false;
  bool _testing = false;
  bool _showKey = false;
  bool _tested = false;
  String? _testError;
  String? _inputError;
  bool _failed = false;
  bool _allowClose = false;
  Future<void> _cancel() async {
    if (_saving || _testing) return;
    if (_controller.text != widget.initialKey) {
      final l = AppLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.unsavedTitle),
          content: Text(l.unsavedHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.keepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.discardChanges),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _testing) return;
    if (_controller.text.trim().isNotEmpty &&
        !isValidMetadataApiKey(_controller.text)) {
      setState(
        () => _inputError = AppLocalizations.of(context).metadataKeyFormat,
      );
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.store.save(_controller.text.trim());
      if (mounted) {
        setState(() => _allowClose = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _test() async {
    if (_saving || _testing) return;
    final l = AppLocalizations.of(context);
    if (!isValidMetadataApiKey(_controller.text)) {
      setState(() {
        _inputError = _controller.text.trim().isEmpty
            ? l.metadataKeyRequired
            : l.metadataKeyFormat;
        _tested = false;
        _testError = null;
      });
      return;
    }
    setState(() {
      _testing = true;
      _tested = false;
      _testError = null;
      _inputError = null;
    });
    try {
      await widget.service.testApiKey(_controller.text.trim());
      if (mounted) setState(() => _tested = true);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _testError = error is MetadataException ? error.code : 'network',
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        title: Text(l.metadataConfigure),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.metadataSetupHint),
                TextButton(
                  onPressed: () => _openLink(
                    context,
                    Uri.https('www.omdbapi.com', '/apikey.aspx'),
                  ),
                  child: Text(l.metadataGetKey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: !_saving && !_testing,
                  obscureText: !_showKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _test(),
                  onChanged: (_) => setState(() {
                    _tested = false;
                    _testError = null;
                    _inputError = null;
                    _failed = false;
                  }),
                  decoration: InputDecoration(
                    labelText: l.metadataApiKey,
                    border: const OutlineInputBorder(),
                    helperText: l.metadataKeyFormat,
                    helperMaxLines: 3,
                    errorText: _inputError,
                    errorMaxLines: 3,
                    suffixIcon: IconButton(
                      tooltip: _showKey
                          ? l.passwordHideTooltip
                          : l.passwordShowTooltip,
                      onPressed: _saving || _testing
                          ? null
                          : () => setState(() => _showKey = !_showKey),
                      icon: Icon(
                        _showKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving || _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(_testing ? l.metadataTesting : l.metadataTestKey),
                ),
                if (_tested || _testError != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _tested
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _tested
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _tested
                                  ? l.metadataTestSuccess
                                  : _testError == 'key'
                                  ? l.metadataKeyFailed
                                  : _testError == 'limit'
                                  ? l.metadataLimit
                                  : l.metadataTestFailed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(l.metadataRemoveKeyHint),
                if (_failed) Text(l.settingsWriteHint),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _testing ? null : _cancel,
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving || _testing ? null : _save,
            child: Text(l.saveChanges),
          ),
        ],
      ),
    );
  }
}
