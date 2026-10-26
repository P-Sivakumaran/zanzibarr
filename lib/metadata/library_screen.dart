import 'package:flutter/material.dart';
import '../player/watchlist.dart';
import 'metadata_service.dart';
import 'title_library.dart';
import 'artwork.dart';

class TitleCard extends StatelessWidget {
  const TitleCard({
    super.key,
    required this.title,
    required this.onOpen,
    this.artworkLoader,
  });
  final ArtworkLoader? artworkLoader;
  final MediaTitle title;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${title.title}, ${title.kind == 'series' ? 'TV show' : 'Film'}, ${title.year}',
    button: true,
    child: Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleArtwork(
                url: title.poster,
                title: title.title,
                loader: artworkLoader,
              ),
              const SizedBox(height: 12),
              Text(
                title.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${title.year} / ${title.kind == 'series' ? 'TV show' : 'Film'}',
              ),
              if (title.ratings['IMDb'] != null)
                Text('IMDb ${title.ratings['IMDb']}'),
            ],
          ),
        ),
      ),
    ),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.onOpen,
    this.store,
    this.watchlistStore,
    this.artworkLoader,
    this.artworkPreferences,
    this.onPlaylists,
  });
  final VoidCallback? onPlaylists;
  final ArtworkPreferences? artworkPreferences;
  final Future<void> Function(MediaTitle) onOpen;
  final ArtworkLoader? artworkLoader;
  final TitleLibraryStore? store;
  final WatchlistStore? watchlistStore;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final _store = widget.store ?? TitleLibraryStore.shared;
  List<MediaTitle> _titles = [];
  String _filter = 'all', _sort = 'recent';
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _store.load();
      final tracked = await (widget.watchlistStore ?? WatchlistStore()).load();
      final ids = saved.map((t) => t.imdbId).toSet();
      final titles = [
        ...saved,
        for (final t in tracked)
          if (!ids.contains(t.imdbId))
            MediaTitle(
              imdbId: t.imdbId,
              title: t.title,
              year: '',
              kind: 'series',
            ),
      ];
      if (mounted) {
        setState(() {
          _titles = titles;
          _error = null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Your library could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = _titles
        .where((t) => _filter == 'all' || t.kind == _filter)
        .toList();
    if (_sort == 'title') {
      titles.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    if (_sort == 'year') titles.sort((a, b) => b.year.compareTo(a.year));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My library'),
        actions: [
          if (widget.onPlaylists != null)
            TextButton.icon(
              onPressed: widget.onPlaylists,
              icon: const Icon(Icons.playlist_play),
              label: const Text('Playlists'),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              (constraints.maxWidth /
                      (MediaQuery.textScalerOf(context).scale(180)))
                  .floor()
                  .clamp(1, 5);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved titles',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Saved films and tracked shows. Open a title to explore details and find releases.',
                      ),
                      const SizedBox(height: 16),
                      ArtworkSettings(preferences: widget.artworkPreferences),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final f in {
                            'all': 'All titles',
                            'movie': 'Films',
                            'series': 'TV shows',
                          }.entries)
                            ChoiceChip(
                              label: Text(f.value),
                              selected: _filter == f.key,
                              onSelected: (_) =>
                                  setState(() => _filter = f.key),
                            ),
                          SizedBox(
                            width: (constraints.maxWidth - 48).clamp(120, 240),
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _sort,
                              onChanged: (v) => setState(() => _sort = v!),
                              items: [
                                for (final s in {
                                  'recent': 'Recently saved',
                                  'title': 'Title A-Z',
                                  'year': 'Year',
                                }.entries)
                                  DropdownMenuItem(
                                    value: s.key,
                                    child: Text(s.value),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null) ...[
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                      if (!_loading && _error == null && titles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No titles here yet. Browse films & TV and save a title, or track a show.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverList.builder(
                  itemCount: (titles.length / columns).ceil(),
                  itemBuilder: (context, row) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) const SizedBox(width: 20),
                          Expanded(
                            child: row * columns + col < titles.length
                                ? TitleCard(
                                    title: titles[row * columns + col],
                                    artworkLoader: widget.artworkLoader,
                                    onOpen: () async {
                                      await widget.onOpen(
                                        titles[row * columns + col],
                                      );
                                      await _load();
                                    },
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
