import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../metadata/metadata_screen.dart';
import '../metadata/metadata_service.dart';
import '../ui/error_feedback.dart';
import '../player/player_screen.dart';
import '../settings/indexer_settings.dart';
import '../settings/settings_screen.dart';
import '../settings/ui_preferences.dart';
import '../src/rust/api/search.dart';
import '../tv_focus.dart';
import 'release_search_selection.dart';
import 'structured_search_dialog.dart';

/// FRB `newznabSearchMany` imzası; testlerde sahte enjekte edilebilir.
typedef NewznabSearchFn =
    Future<SearchManyResultDto> Function(
      List<IndexerConfigDto> configs,
      String query,
      int limit,
      int offset,
    );

/// FRB `newznabDownloadNzb` imzası; testlerde sahte enjekte edilebilir.
typedef NewznabDownloadFn =
    Future<String> Function(
      IndexerConfigDto config,
      String nzbUrl,
      String suggestedName,
    );

/// Newznab indexer'da arama yapıp sonucu NZB indirmeden oynatıcıya bağlayan
/// ekran.
///
/// Ayarlar OS secure storage'dan okunur; API anahtarı ve `nzbUrl` hiçbir
/// zaman loglanmaz. Varsayılan arama/indirme gerçek FRB köprüsünü çağırır,
/// testler [searchFn]/[downloadFn]/[onDownloaded] ile sahte kurar.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.store,
    this.searchFn,
    this.downloadFn,
    this.onDownloaded,
    this.uiPreferences,
    this.metadataService,
    this.metadataStore,
    this.capsFn,
    this.initialSelection,
  });

  /// Testlerde sahte depo enjekte edebilmek için; null ise gerçek depo kullanılır.
  final IndexerSettingsStore? store;

  /// Null ise FRB `newznabSearch` kullanılır.
  final NewznabSearchFn? searchFn;

  /// Null ise FRB `newznabDownloadNzb` kullanılır.
  final NewznabDownloadFn? downloadFn;

  /// İndirme bitince çağrılır; null ise [PlayerScreen]'e push edilir.
  /// Testlerde oynatıcının native çağrılarını atlamak için kullanılır.
  final ValueChanged<String>? onDownloaded;

  /// Ayarlar ekranına taşınır; oradaki Uygulama bölümü (dil/tema) ve TV
  /// autofocus hedefi için gerekli.
  final UiPreferencesController? uiPreferences;
  final MetadataService? metadataService;
  final MetadataSettingsStore? metadataStore;
  final NewznabCapsFn? capsFn;

  /// "Sıradaki" kartından açıldığında alan önceden doldurulur; kullanıcı
  /// aramayı kendisi başlatana kadar otomatik arama yapılmaz.
  final ReleaseSearchSelection? initialSelection;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _pageSize = 50;

  late final IndexerSettingsStore _store =
      widget.store ?? IndexerSettingsStore();
  late final NewznabSearchFn _searchFn = widget.searchFn ?? _defaultSearch;
  late final NewznabDownloadFn _downloadFn =
      widget.downloadFn ?? _defaultDownload;

  final _queryController = TextEditingController();
  late final _metadataService = widget.metadataService ?? MetadataService();
  late final _metadataStore = widget.metadataStore ?? MetadataSettingsStore();
  ReleaseSearchSelection? _selection;
  ReleaseSearchSelection? _activeSelection;
  bool _settingSelection = false;
  final _caps = <String, Future<IndexerCapsDto?>>{};

  /// TV kumandasında aşağı ok alandan çıkıp sonuç kartlarına inebilsin diye
  /// D-pad gezintili odak düğümü (issue #4).
  late final _queryFocusNode = dpadTraversalFocusNode(_queryController);

  List<IndexerProfile> _profiles = [];
  bool _loadingSettings = true;
  bool _settingsLoadFailed = false;

  List<SearchItemDto>? _items;
  int? _total;
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextOffset = 0;
  int _generation = 0;
  String _activeQuery = '';
  List<IndexerConfigDto> _activeConfigs = [];
  List<String> _failedIndexers = [];
  Uint32List? _sourceOffsets;
  String? _pageError;
  Object? _error;

  /// Şu an NZB'si indirilen öğenin listedeki sırası; spinner burada gösterilir.
  int? _busyIndex;

  /// Sonuçlar gelince odak ilk karta taşınır; TV kumandası kullanıcısı
  /// IME'den çıkınca doğrudan listeyi dolaşmaya başlar (issue #4).
  final _firstResultFocusNode = FocusNode();
  final _nextPageFocusNode = FocusNode();
  int? _focusAfterLoadIndex;

  Future<SearchManyResultDto> _defaultSearch(
    List<IndexerConfigDto> configs,
    String query,
    int limit,
    int offset,
  ) => newznabSearchMany(
    configs: configs,
    query: query,
    limit: limit,
    offset: offset,
    offsets: offset == 0 ? null : _sourceOffsets,
  );

  static Future<String> _defaultDownload(
    IndexerConfigDto config,
    String nzbUrl,
    String suggestedName,
  ) async {
    // Android'de Rust tarafının std::env::temp_dir() kullanımı çalışmaz
    // (TMPDIR yok, /tmp yazılamaz); NZB uygulamanın önbellek dizinine iner.
    // Masaüstünde de aynı dizin kullanılır (izin gerektirmez).
    final cacheDir = await getTemporaryDirectory();
    return newznabDownloadNzb(
      config: config,
      nzbUrl: nzbUrl,
      suggestedName: suggestedName,
      downloadDir: cacheDir.path,
    );
  }

  @override
  void initState() {
    super.initState();
    // Temizle düğmesi yalnızca metin varken görünsün.
    _queryController.addListener(
      () => setState(() {
        if (!_settingSelection &&
            _queryController.text != _selection?.fallbackQuery) {
          _selection = null;
        }
      }),
    );
    final initial = widget.initialSelection;
    if (initial != null) {
      _settingSelection = true;
      _queryController.text = initial.fallbackQuery;
      _settingSelection = false;
      _selection = initial;
    }
    _loadSettings();
  }

  @override
  void dispose() {
    if (widget.metadataService == null) _metadataService.close();
    _queryController.dispose();
    _queryFocusNode.dispose();
    _firstResultFocusNode.dispose();
    _nextPageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loadingSettings = true);
    try {
      final profiles = await _store.load();
      if (!mounted) return;
      setState(() {
        if (!_sameProfiles(_profiles, profiles)) {
          _caps.clear();
          ++_generation;
          _items = null;
          _total = null;
          _hasMore = false;
          _loadingMore = false;
          _searching = false;
          _error = null;
        }
        _profiles = profiles;
        _loadingSettings = false;
        _settingsLoadFailed = false;
      });
    } catch (_) {
      // Keep unreadable credentials distinct from an unconfigured indexer.
      if (!mounted) return;
      setState(() {
        _loadingSettings = false;
        _settingsLoadFailed = true;
        ++_generation;
        _searching = false;
        _loadingMore = false;
      });
    }
  }

  bool _sameProfiles(List<IndexerProfile> a, List<IndexerProfile> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].baseUrl != b[i].baseUrl ||
          a[i].id != b[i].id ||
          a[i].nickname != b[i].nickname ||
          a[i].apiKey != b[i].apiKey ||
          a[i].enabled != b[i].enabled) {
        return false;
      }
    }
    return true;
  }

  List<IndexerProfile> get _enabledProfiles =>
      _profiles.where((p) => p.enabled && p.isComplete).toList();

  List<IndexerConfigDto> get _enabledConfigs => [
    for (final p in _enabledProfiles)
      IndexerConfigDto(
        id: p.id,
        baseUrl: p.baseUrl,
        apiKey: p.apiKey,
        nickname: p.displayName,
      ),
  ];

  /// Sonuç kartındaki `source_indexer` rozetinden gerçek kimlik bilgilerine
  /// döner; indirme/NZB isteği bunu kullanır. Arama sonrası profil
  /// silinmiş/değişmişse (nadiren) null döner — indirme kullanıcıya hata
  /// gösterir.
  IndexerConfigDto? _configFor(SearchItemDto item) {
    for (final config in _activeConfigs) {
      if (item.sourceId != null
          ? config.id == item.sourceId
          : config.nickname == item.sourceIndexer) {
        return config;
      }
    }
    return null;
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    final configs = _enabledConfigs;
    if (query.isEmpty ||
        _searching ||
        _busyIndex != null ||
        _loadingSettings ||
        _settingsLoadFailed ||
        configs.isEmpty) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _loadingMore = false;
      _error = null;
      _pageError = null;
      _activeQuery = query;
      _activeSelection = _selection;
      _activeConfigs = configs;
      _failedIndexers = [];
      _sourceOffsets = null;
      _focusAfterLoadIndex = null;
    });
    try {
      final prepared = await _prepareConfigs(configs, _activeSelection);
      if (!mounted || generation != _generation) return;
      _activeConfigs = prepared;
      final result = await _searchFn(prepared, query, _pageSize, 0);
      final page = result.page;
      if (!mounted || generation != _generation) return;
      if (result.failedIndexers.length == configs.length &&
          page.items.isEmpty) {
        throw StateError('All indexers failed');
      }
      setState(() {
        _sourceOffsets = result.nextOffsets;
        _items = _uniqueItems(page.items);
        _nextOffset = result.nextOffsets == null ? page.items.length : 1;
        _hasMore =
            result.hasMore ??
            (page.items.isNotEmpty &&
                (page.total != null
                    ? _nextOffset < page.total!.toInt()
                    : page.items.length >= _pageSize));
        _total = page.total?.toInt();
        _failedIndexers = result.failedIndexers;
        _searching = false;
      });
      if (page.items.isNotEmpty) {
        // Klavyeden "ara" eylemi alan odağını düşürür; D-pad zinciri
        // kopmasın diye odak ilk sonuç kartına taşınır.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _firstResultFocusNode.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _searching = false;
      });
    }
  }

  Future<List<IndexerConfigDto>> _prepareConfigs(
    List<IndexerConfigDto> configs,
    ReleaseSearchSelection? selection,
  ) async {
    if (selection == null) return configs;
    return Future.wait([
      for (final config in configs)
        (() async {
          final key = config.id ?? config.baseUrl;
          final future = _caps.putIfAbsent(key, () async {
            try {
              return await (widget.capsFn ??
                  (c) => newznabCheckCaps(config: c))(config);
            } catch (_) {
              return null;
            }
          });
          final caps = await future;
          // Failed capability discovery uses title search and can retry next time.
          if (caps == null && identical(_caps[key], future)) _caps.remove(key);
          final params = selection.kind == 'movie'
              ? (caps?.movieSearchAvailable == true
                    ? caps?.movieSearchParams
                    : null)
              : (caps?.tvSearchAvailable == true ? caps?.tvSearchParams : null);
          return IndexerConfigDto(
            id: config.id,
            baseUrl: config.baseUrl,
            apiKey: config.apiKey,
            nickname: config.nickname,
            structured: selection.toDto(params ?? const []),
          );
        })(),
    ]);
  }

  Future<void> _applySelection(ReleaseSearchSelection selection) async {
    if (!mounted) return;
    ++_generation;
    _settingSelection = true;
    _queryController.text = selection.fallbackQuery;
    _settingSelection = false;
    setState(() {
      _selection = selection;
      _searching = false;
      _loadingMore = false;
    });
    await _search();
  }

  Future<void> _openMetadata([String? hint]) async {
    final selection = await Navigator.of(context).push<ReleaseSearchSelection>(
      MaterialPageRoute(
        builder: (_) => MetadataScreen(
          service: _metadataService,
          store: _metadataStore,
          initialQuery: hint ?? _queryController.text.trim(),
        ),
      ),
    );
    if (selection != null) await _applySelection(selection);
  }

  Future<void> _openStructured() async {
    final selection = await showStructuredSearchDialog(
      context,
      initial: _selection,
      title: _queryController.text.trim(),
    );
    if (selection != null) await _applySelection(selection);
  }

  List<SearchItemDto> _uniqueItems(Iterable<SearchItemDto> items) {
    String titleKey(String title) =>
        title.toLowerCase().replaceAll(RegExp(r'[\s._\-\[\]()]+'), '');
    final kept = <SearchItemDto>[];
    for (final item in items) {
      final duplicate = kept.any((existing) {
        if (existing.nzbUrl == item.nzbUrl) return true;
        if (titleKey(existing.title) != titleKey(item.title)) return false;
        final a = existing.sizeBytes;
        final b = item.sizeBytes;
        if (a == null || b == null) return a == b;
        final high = a > b ? a : b;
        return (a - b).abs() <= high ~/ BigInt.from(100);
      });
      if (!duplicate) kept.add(item);
    }
    return kept;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _searching || !_hasMore || _busyIndex != null) return;
    final generation = _generation;
    final offset = _nextOffset;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final result = await _searchFn(
        _activeConfigs,
        _activeQuery,
        _pageSize,
        offset,
      );
      final page = result.page;
      if (!mounted || generation != _generation) return;
      if (page.items.isEmpty &&
          result.failedIndexers.isNotEmpty &&
          result.nextOffsets != null &&
          result.nextOffsets!.asMap().entries.every(
            (entry) =>
                entry.value == 4294967295 ||
                entry.value == _sourceOffsets?[entry.key],
          )) {
        throw StateError('No indexer advanced');
      }
      final previousCount = _items?.length ?? 0;
      setState(() {
        _items = _uniqueItems([...?_items, ...page.items]);
        _focusAfterLoadIndex = _items!.length > previousCount
            ? previousCount
            : null;
        _nextOffset += page.items.length;
        _sourceOffsets = result.nextOffsets;
        // A cursor remains nonzero even when an entire page deduplicates away.
        if (_sourceOffsets != null) _nextOffset = 1;
        _total = page.total?.toInt() ?? _total;
        _hasMore =
            result.hasMore ??
            (page.items.isNotEmpty &&
                (_total != null
                    ? _nextOffset < _total!
                    : page.items.length >= _pageSize));
        _failedIndexers = result.failedIndexers;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _generation &&
            _nextPageFocusNode.context != null) {
          _nextPageFocusNode.requestFocus();
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _pageError = AppLocalizations.of(context).searchPageFailed,
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _downloadAndPlay(int index) async {
    if (_busyIndex != null) return;
    final item = _items![index];
    final config = _configFor(item);
    if (config == null) {
      // Profil arama sırasından beri silinmiş/değişmiş olabilir.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).searchDownloadHint),
        ),
      );
      return;
    }
    setState(() => _busyIndex = index);
    try {
      final path = await _downloadFn(config, item.nzbUrl, item.title);
      if (!mounted) return;
      final onDownloaded = widget.onDownloaded;
      if (onDownloaded != null) {
        onDownloaded(path);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerScreen(
              nzbPath: path,
              imdbId: _activeSelection?.imdbId,
              season: item.season ?? _activeSelection?.season,
              episode: item.episode ?? _activeSelection?.episode,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).searchDownloadHint),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIndex = null);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          uiPreferences: widget.uiPreferences,
          indexerStore: _store,
          initialSection: SettingsSection.indexer,
        ),
      ),
    );
    // Ayarlardan dönüldüğünde indexer yeni girilmiş olabilir.
    await _loadSettings();
    if (mounted &&
        _enabledProfiles.isNotEmpty &&
        _queryController.text.trim().isNotEmpty) {
      await _search();
    }
  }

  bool _savingProfiles = false;
  Future<void> _toggleSearchProfile(int index) async {
    if (_savingProfiles) return;
    setState(() => _savingProfiles = true);
    try {
      await _store.save([
        for (var i = 0; i < _profiles.length; i++)
          i == index
              ? _profiles[i].copyWith(enabled: !_profiles[i].enabled)
              : _profiles[i],
      ]);
      await _loadSettings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsWriteHint),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfiles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.metadataBrowseTitle,
            onPressed: _busyIndex == null ? _openMetadata : null,
            icon: const Icon(Icons.movie_filter_outlined),
          ),
          IconButton(
            tooltip: l10n.structuredSearchTitle,
            onPressed: _busyIndex == null ? _openStructured : null,
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<int>(
            tooltip: l10n.indexerSectionTitle,
            enabled:
                !_loadingSettings && !_savingProfiles && _busyIndex == null,
            icon: const Icon(Icons.filter_alt_outlined),
            onSelected: _toggleSearchProfile,
            itemBuilder: (_) => [
              for (var i = 0; i < _profiles.length; i++)
                CheckedPopupMenuItem(
                  value: i,
                  checked: _profiles[i].enabled,
                  child: Text(_profiles[i].displayName),
                ),
            ],
          ),
          IconButton(
            tooltip: l10n.goToIndexerSettings,
            onPressed: _busyIndex == null ? _openSettings : null,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
          tooltip: l10n.backTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          l10n.searchTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    focusNode: _queryFocusNode,
                    // TV kumandasında D-pad gezintisi metin alanından başlar.
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _queryController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.searchClearTooltip,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _queryController.clear();
                                ++_generation;
                                setState(() {
                                  _searching = false;
                                  _loadingMore = false;
                                  _pageError = null;
                                  _hasMore = false;
                                  _items = null;
                                  _total = null;
                                  _error = null;
                                });
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: l10n.searchTooltip,
                  onPressed:
                      _searching ||
                          _busyIndex != null ||
                          _loadingSettings ||
                          _enabledProfiles.isEmpty
                      ? null
                      : _search,
                  icon: const Icon(Icons.search_rounded, size: 20),
                ),
              ],
            ),
          ),
          if (_total != null && _items != null && !_searching)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(
                  (_items!.length < _total!
                      ? l10n.showingResults(_items!.length, _total!)
                      : l10n.searchResultsTotal(_total!)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
          if (_selection != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                l10n.structuredSearchActive,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(child: _buildBody(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loadingSettings) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_settingsLoadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsLoadHint),
            TextButton(onPressed: _loadSettings, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (_enabledProfiles.isEmpty) {
      return _IndexerMissing(onOpenSettings: _openSettings);
    }
    if (_searching) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error case final error?) {
      return _SearchError(
        error: error,
        details: safeErrorDetails(
          error,
          secrets: [for (final p in _profiles) p.apiKey],
        ),
        onRetry: _search,
        onSettings: _openSettings,
      );
    }
    final items = _items;
    if (items == null) {
      return _HintView(
        icon: Icons.travel_explore_rounded,
        message: l10n.searchEmptyHint,
      );
    }
    if (items.isEmpty && !_hasMore && _failedIndexers.isEmpty) {
      return _HintView(
        icon: Icons.search_off_rounded,
        message: l10n.searchNoResults,
      );
    }
    return Column(
      children: [
        if (_failedIndexers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _PartialFailureBanner(
              message: l10n.indexerPartialFailureHint(
                _failedIndexers.length,
                _activeConfigs.length,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: items.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => index == items.length
                ? Column(
                    children: [
                      if (_pageError != null)
                        Text(
                          _pageError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      OutlinedButton(
                        onPressed: _loadingMore || _busyIndex != null
                            ? null
                            : _loadMore,
                        child: Text(
                          _loadingMore ? l10n.loadingMore : l10n.loadMore,
                        ),
                      ),
                    ],
                  )
                : _SearchResultCard(
                    onMetadata: () => _openMetadata(
                      items[index].imdbId ??
                          releaseTitleHint(items[index].title),
                    ),
                    item: items[index],
                    busy: _busyIndex == index,
                    enabled: _busyIndex == null,
                    focusNode: index == 0
                        ? _firstResultFocusNode
                        : index == _focusAfterLoadIndex
                        ? _nextPageFocusNode
                        : null,
                    onTap: () => _downloadAndPlay(index),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Tek arama sonucu kartı: tür simgesi, başlık, rozetler ve sağda boyut/yaş.
class _SearchResultCard extends StatefulWidget {
  const _SearchResultCard({
    required this.item,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onMetadata,
    this.focusNode,
  });

  final SearchItemDto item;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onMetadata;

  /// İlk sonuç kartında kullanılır: arama bitince odak buraya taşınır.
  final FocusNode? focusNode;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _focused = false;

  static IconData _mediaIcon(String mediaKind) => switch (mediaKind) {
    'movie' => Icons.movie_outlined,
    'tv' => Icons.tv_rounded,
    _ => Icons.insert_drive_file_outlined,
  };

  /// GB/MB biçiminde boyut; `null` ise boş döner (gösterilmez).
  static String _formatSize(BigInt sizeBytes) {
    final bytes = sizeBytes.toInt();
    const giga = 1024 * 1024 * 1024;
    const mega = 1024 * 1024;
    if (bytes >= giga) return '${(bytes / giga).toStringAsFixed(1)} GB';
    if (bytes >= mega) return '${(bytes / mega).round()} MB';
    return '<1 MB';
  }

  /// Yayın yaşını gün/ay/yıl kısaltmasıyla verir; `null` ise boş döner.
  static String _formatAge(int publishedEpochSecs, bool turkish) {
    final published = DateTime.fromMillisecondsSinceEpoch(
      publishedEpochSecs * 1000,
    );
    var days = DateTime.now().difference(published).inDays;
    if (days < 0) days = 0;
    if (days < 31) return turkish ? '$days g' : '${days}d';
    if (days < 365) {
      final months = days ~/ 30;
      return turkish ? '$months ay' : '${months}mo';
    }
    return '${days ~/ 365} y';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
    final sizeText = item.sizeBytes == null
        ? null
        : _formatSize(item.sizeBytes!);
    final ageText = item.publishedEpochSecs == null
        ? null
        : _formatAge(item.publishedEpochSecs!.toInt(), isTurkish);
    return Material(
      color: foreground.withValues(alpha: _focused ? 0.08 : 0.035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _focused ? accent : foreground.withValues(alpha: 0.075),
          width: _focused ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        focusNode: widget.focusNode,
        hoverColor: foreground.withValues(alpha: 0.045),
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (!compact)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.busy
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: foreground.withValues(alpha: 0.7),
                          ),
                        )
                      : Icon(
                          _mediaIcon(item.mediaKind),
                          size: 19,
                          color: foreground.withValues(alpha: 0.7),
                        ),
                ),
              if (!compact) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (compact)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          [
                            ?sizeText,
                            ?ageText,
                            if (item.year != null) '${item.year}',
                          ].join(' · '),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (item.badges.isNotEmpty ||
                        item.sourceIndexer.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (item.sourceIndexer.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                item.sourceIndexer,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          for (final badge in item.badges)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: foreground.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: foreground.withValues(alpha: 0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).releaseDetails,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppLocalizations.of(context).releaseDetails),
                    content: SingleChildScrollView(
                      child: SelectableText(item.title),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onMetadata();
                        },
                        child: Text(
                          AppLocalizations.of(context).metadataBrowseTitle,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          MaterialLocalizations.of(context).closeButtonLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (!compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (sizeText != null)
                      Text(
                        sizeText,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (ageText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          ageText,
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.72),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (item.year != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${item.year}',
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.72),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indexer ayarları eksikken gösterilen yönlendirme görünümü.
class _IndexerMissing extends StatelessWidget {
  const _IndexerMissing({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 32,
                color: foreground.withValues(alpha: 0.54),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.indexerMissingHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(l10n.goToIndexerSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arama hatası; oynatıcıdaki _ErrorView tarzının sade hâli.
class _SearchError extends StatelessWidget {
  const _SearchError({
    required this.error,
    required this.details,
    required this.onRetry,
    required this.onSettings,
  });

  final Object error;
  final String details;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  friendlyError(
                    context,
                    error,
                    fallback: l10n.searchFailedHint,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ExpansionTile(
                  title: Text(l10n.technicalDetailsLabel),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(details),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onSettings,
                  child: Text(l10n.goToIndexerSettings),
                ),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bazı indexer'lar yanıt vermediğinde arama sonuçlarının üstünde gösterilen
/// uyarı; sonuçlar yine de kalan indexer'lardan gösterilir.
class _PartialFailureBanner extends StatelessWidget {
  const _PartialFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final warning = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: warning, fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş durum ipucu görünümü (henüz arama yapılmadı / sonuç yok).
class _HintView extends StatelessWidget {
  const _HintView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: foreground.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.72),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
