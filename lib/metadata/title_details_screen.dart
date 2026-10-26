import '../player/episode_catalog.dart';
import '../player/series_preferences.dart';
import '../settings/series_settings_screen.dart';
import 'metadata_visuals.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../player/playback_history.dart';
import '../player/watchlist.dart';
import '../search/release_search_selection.dart';
import 'metadata_service.dart';
import 'metadata_enrichment.dart';
import 'title_information.dart';
import 'film_blurb.dart';
import 'trailer_panel.dart';
import 'title_library.dart';
import 'artwork.dart';

class TitleDetailsScreen extends StatefulWidget {
  const TitleDetailsScreen({
    super.key,
    required this.title,
    required this.service,
    required this.apiKey,
    this.providerName,
    this.watchlistStore,
    this.libraryStore,
    this.historyStore,
    this.onResume,
    this.artworkLoader,
    this.enrichment,
    this.seriesPreferences,
  });
  final ArtworkLoader? artworkLoader;
  final MetadataEnrichment? enrichment;
  final SeriesPreferences? seriesPreferences;
  final MediaTitle title;
  final MetadataService service;
  final String apiKey;
  final String? providerName;
  final WatchlistStore? watchlistStore;
  final TitleLibraryStore? libraryStore;
  final PlaybackHistoryStore? historyStore;
  final Future<void> Function(PlaybackHistoryEntry)? onResume;
  @override
  State<TitleDetailsScreen> createState() => _TitleDetailsScreenState();
}

class _TitleDetailsScreenState extends State<TitleDetailsScreen> {
  late final _enrichment = widget.enrichment ?? MetadataEnrichment();
  MediaTitle? _base;
  late Future<MediaTitle?> _details = _loadDetails();
  bool _refreshFailed = false;
  Future<MediaTitle?> _loadDetails() async {
    _refreshFailed = false;
    MediaTitle? title;
    try {
      title = await widget.service.details(widget.apiKey, widget.title.imdbId);
      _refreshFailed = title == null;
    } catch (_) {
      _refreshFailed = true;
    }
    title ??= widget.title;
    if (mounted) setState(() => _base = title);
    final enriched = await _enrichment.enrich(title);
    if (mounted && enriched.kind == 'series' && _episodes == null) {
      setState(() {
        _episodes = _loadSeason(enriched, _season);
      });
    }
    return enriched;
  }

  @override
  void dispose() {
    if (widget.enrichment == null) _enrichment.close();
    _seasonFocus.dispose();
    super.dispose();
  }

  late final _library = widget.libraryStore ?? TitleLibraryStore.shared;
  late final _watchlist = widget.watchlistStore ?? WatchlistStore();
  List<PlaybackHistoryEntry> _history = [];
  bool _saved = false, _tracked = false, _ready = false, _busy = false;
  String? _storageError;
  final _episodeSectionKey = GlobalKey();
  final _seasonFocus = FocusNode();
  int _season = 1;
  Future<List<MediaEpisode>>? _episodes;
  late final _series = widget.seriesPreferences ?? SeriesPreferences.shared;
  @override
  void initState() {
    super.initState();
    if (widget.title.kind == 'series') _series.load();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final titles = await _library.load();
      final tracked = await _watchlist.isTracked(widget.title.imdbId);
      final history = await (widget.historyStore ?? PlaybackHistoryStore())
          .load();
      if (!mounted) return;
      setState(() {
        _saved = titles.any((t) => t.imdbId == widget.title.imdbId);
        _tracked = tracked;
        _history = history;
        _ready = true;
        _storageError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _storageError =
              'Library or history could not be loaded. Retry before saving.',
        );
      }
    }
  }

  Future<void> _save(MediaTitle media, {bool track = false}) async {
    if (_busy || !_ready) return;
    setState(() => _busy = true);
    try {
      if (track) {
        if (_tracked) {
          await _watchlist.untrack(media.imdbId);
        } else {
          await _watchlist.track(media.imdbId, media.title);
        }
      } else {
        if (_saved) {
          await _library.remove(media.imdbId);
        } else {
          await _library.save(media);
        }
      }
      if (mounted) {
        setState(() {
          if (track) {
            _tracked = !_tracked;
          } else {
            _saved = !_saved;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is LibraryFull
                  ? 'Your library is full (300 titles). Remove a saved title first.'
                  : 'Could not save changes. Your library is unchanged.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).metadataLinkFailed),
        ),
      );
    }
  }

  void _find(MediaTitle media, [int? episode]) => Navigator.pop(
    context,
    ReleaseSearchSelection(
      title: media.title,
      kind: media.kind == 'series' ? 'tv' : 'movie',
      imdbId: media.imdbId,
      year: int.tryParse(media.year.split(RegExp(r'\D')).first),
      season: episode == null ? null : _season,
      episode: episode,
      autoPick: episode != null && _series.ready && _series.value.autoSelect,
      runtimeMinutes: episode == null
          ? null
          : _seasonData
                .where((e) => e.number == episode)
                .firstOrNull
                ?.runtimeMinutes,
    ),
  );
  List<MediaEpisode> _seasonData = [];
  Future<List<MediaEpisode>> _loadSeason(MediaTitle media, int season) async {
    final episodes = await EpisodeCatalog(
      service: widget.service,
      enrichment: _enrichment,
      apiKey: widget.apiKey,
    ).season(media, season);
    if (mounted && season == _season) _seasonData = episodes;
    if (_tracked) {
      try {
        await _watchlist.markChecked(media.imdbId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Episodes loaded, but the check reminder could not be saved.',
              ),
            ),
          );
        }
      }
    }
    return episodes;
  }

  PlaybackHistoryEntry? _entry(int episode) => _history
      .where(
        (e) =>
            e.imdbId == widget.title.imdbId &&
            e.season == _season &&
            e.episode == episode,
      )
      .firstOrNull;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _series,
      builder: (context, _) => FutureBuilder<MediaTitle?>(
        future: _details,
        builder: (context, snapshot) {
          final media = snapshot.data ?? _base ?? widget.title;
          final source = widget.providerName ?? media.provider;
          return Scaffold(
            appBar: AppBar(title: Text(media.title)),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (snapshot.connectionState != ConnectionState.done &&
                          _base == null)
                        const LinearProgressIndicator(),
                      if (snapshot.connectionState != ConnectionState.done &&
                          _base != null)
                        const Text('Checking optional title details...'),
                      if (_refreshFailed ||
                          snapshot.hasError ||
                          (snapshot.connectionState == ConnectionState.done &&
                              snapshot.data == null))
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(l.metadataFailed),
                            TextButton(
                              onPressed: () => setState(() {
                                _details = _loadDetails();
                              }),
                              child: Text(l.retry),
                            ),
                          ],
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final poster = SizedBox(
                            width: constraints.maxWidth < 620 ? 140 : 240,
                            child: TitleArtwork(
                              url: media.poster,
                              title: media.title,
                              loader: widget.artworkLoader,
                            ),
                          );
                          final info = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                media.kind == 'series'
                                    ? l.metadataSeries
                                    : l.metadataMovie,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                media.title,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                [
                                  media.year,
                                  media.certification,
                                  media.genre,
                                  media.runtime,
                                ].where((v) => v.isNotEmpty).join(' / '),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Text(filmBlurb(media)),
                              ),
                              RatingMeters(media: media),
                              if (media.ratings.isEmpty)
                                Text(l.metadataNoRatings),
                              const SizedBox(height: 12),
                              Text(
                                source == 'OMDb'
                                    ? l.metadataAttribution
                                    : 'Metadata and ratings supplied by $source',
                              ),
                              if (media.fetchedAt != null)
                                Text(
                                  'Fetched ${media.fetchedAt!.toLocal().toString().split('.').first} / cached up to 6 hours',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (widget.onResume != null &&
                                      media.kind == 'movie' &&
                                      _history.any(
                                        (e) =>
                                            e.imdbId == media.imdbId &&
                                            !e.isCompleted,
                                      ))
                                    FilledButton.icon(
                                      onPressed: () async {
                                        await widget.onResume!(
                                          _history.firstWhere(
                                            (e) =>
                                                e.imdbId == media.imdbId &&
                                                !e.isCompleted,
                                          ),
                                        );
                                        await _loadLocal();
                                      },
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Resume saved release'),
                                    ),
                                  FilledButton.icon(
                                    onPressed: media.kind != 'series'
                                        ? () => _find(media)
                                        : () async {
                                            final target = _episodeSectionKey
                                                .currentContext;
                                            if (target == null) return;
                                            await Scrollable.ensureVisible(
                                              target,
                                              alignment: 0,
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                            );
                                            if (mounted) {
                                              _seasonFocus.requestFocus();
                                            }
                                          },
                                    icon: Icon(
                                      media.kind == 'series'
                                          ? Icons.list_alt
                                          : Icons.search,
                                    ),
                                    label: Text(
                                      media.kind == 'series'
                                          ? 'Browse episodes'
                                          : l.metadataFindReleases,
                                    ),
                                  ),
                                  if (media.kind == 'series')
                                    OutlinedButton.icon(
                                      onPressed: () => _find(media),
                                      icon: const Icon(Icons.search),
                                      label: const Text('Find series releases'),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: _ready && !_busy
                                        ? () => _save(media)
                                        : null,
                                    icon: Icon(
                                      _saved
                                          ? Icons.bookmark
                                          : Icons.bookmark_add_outlined,
                                    ),
                                    label: Text(
                                      _saved
                                          ? 'Remove from library'
                                          : 'Save to library',
                                    ),
                                  ),
                                  if (media.kind == 'series')
                                    OutlinedButton(
                                      onPressed: _ready && !_busy
                                          ? () => _save(media, track: true)
                                          : null,
                                      child: Text(
                                        _tracked ? l.untrackShow : l.trackShow,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                          return constraints.maxWidth < 620
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    poster,
                                    const SizedBox(height: 20),
                                    info,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    poster,
                                    const SizedBox(width: 32),
                                    Expanded(child: info),
                                  ],
                                );
                        },
                      ),
                      if (media.kind == 'series') ...[
                        const SizedBox(height: 24),
                        Text(
                          'Seasons & episodes',
                          key: _episodeSectionKey,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Text(
                          'Choose an episode, resume a saved release, or find a suitable new one.',
                        ),
                        if (!_series.ready && _series.error != null) ...[
                          const Text(
                            'Episode display settings are unavailable. Retry to apply your saved preferences.',
                          ),
                          TextButton(
                            onPressed: _series.load,
                            child: const Text('Retry episode preferences'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('season-$_season'),
                                focusNode: _seasonFocus,
                                isExpanded: true,
                                initialValue: _season,
                                decoration: const InputDecoration(
                                  labelText: 'Season',
                                ),
                                items: [
                                  for (final season in [
                                    0,
                                    for (
                                      var i = 1;
                                      i <= (media.totalSeasons ?? 1);
                                      i++
                                    )
                                      i,
                                  ])
                                    DropdownMenuItem(
                                      value: season,
                                      child: Text(
                                        season == 0
                                            ? 'Specials'
                                            : 'Season $season',
                                      ),
                                    ),
                                ],
                                onChanged: (season) {
                                  if (season != null) {
                                    setState(() {
                                      _season = season;
                                      _seasonData = [];
                                      _episodes = _loadSeason(media, season);
                                    });
                                  }
                                },
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SeriesSettingsScreen(
                                    preferences: _series,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.tune),
                              label: const Text('Episode display & playback'),
                            ),
                            if (_series.ready && _series.value.autoSelect)
                              const Chip(
                                avatar: Icon(Icons.auto_awesome, size: 18),
                                label: Text('Automatic release choice on'),
                              ),
                          ],
                        ),
                        if (_episodes != null)
                          FutureBuilder<List<MediaEpisode>>(
                            future: _episodes,
                            builder: (context, episodes) {
                              if (episodes.hasError) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Episode catalog unavailable. This provider may not support seasons.',
                                    ),
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _episodes = _loadSeason(media, _season);
                                      }),
                                      child: Text(l.retry),
                                    ),
                                  ],
                                );
                              }
                              if (episodes.connectionState !=
                                      ConnectionState.done ||
                                  !episodes.hasData) {
                                return const LinearProgressIndicator();
                              }
                              if (episodes.data!.isEmpty) {
                                return const Text(
                                  'No episodes supplied for this season.',
                                );
                              }
                              return Column(
                                children: [
                                  for (final episode in episodes.data!)
                                    _episodeRow(media, episode),
                                  if (episodes.data!.any(
                                    (e) => e.still.isNotEmpty,
                                  )) ...[
                                    const SizedBox(height: 12),
                                    Image.asset(
                                      'assets/branding/tmdb.png',
                                      width: 96,
                                      semanticLabel: 'TMDB logo',
                                    ),
                                    const Text(
                                      'Episode imagery and runtimes via TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB.',
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                      ],
                      const SizedBox(height: 24),
                      TrailerPanel(
                        trailer: media.trailer,
                        loading:
                            snapshot.connectionState != ConnectionState.done,
                        configured: _enrichment.trailersConfigured,
                        onConfigured: () => setState(() {
                          _details = _loadDetails();
                        }),
                      ),
                      if (_storageError != null)
                        Wrap(
                          children: [
                            Text(_storageError!),
                            TextButton(
                              onPressed: _loadLocal,
                              child: Text(l.retry),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _link(
                              Uri.https(
                                'www.imdb.com',
                                '/title/${media.imdbId}/',
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('IMDb'),
                          ),
                          TextButton.icon(
                            onPressed: () => _link(
                              Uri.https('www.rottentomatoes.com', '/search', {
                                'search': media.title,
                              }),
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Search Rotten Tomatoes'),
                          ),
                        ],
                      ),
                      const Text(
                        'Audio / subtitles: Unknown until playback. Title languages do not verify release tracks.',
                      ),
                      TitleInformation(
                        media: media,
                        artworkLoader: widget.artworkLoader,
                      ),
                      if (media.plot.isNotEmpty)
                        ExpansionTile(
                          title: const Text('Story synopsis (may reveal plot)'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(media.plot),
                            ),
                          ],
                        ),
                      if (_enrichment.status != null)
                        Text(
                          _enrichment.status!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _episodeRow(MediaTitle media, MediaEpisode episode) {
    final entry = _entry(episode.number);
    final future = episode.isFuture(DateUtils.dateOnly(DateTime.now()));
    final label =
        'S${_season.toString().padLeft(2, '0')} E${episode.number.toString().padLeft(2, '0')}';
    final prefs = _series.value;
    final heading = _series.ready && prefs.showTitles
        ? episode.title
        : 'Episode ${episode.number}';
    final thumbnail = Semantics(
      label: '$label artwork',
      image: true,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _series.ready && prefs.showStills && episode.still.isNotEmpty
            ? TitleArtwork(
                url: episode.still,
                title: heading,
                ratio: 16 / 9,
                loader: widget.artworkLoader,
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline, size: 32),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Text(heading, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          [
            if (episode.aired != null)
              episode.aired!.toIso8601String().split('T').first,
            if (episode.runtimeMinutes != null) '${episode.runtimeMinutes} min',
            if (entry?.isCompleted == true)
              'Watched'
            else if (entry != null)
              'In progress',
            if (future) 'Not aired' else 'Releases not checked',
          ].join(' / '),
        ),
        if (_series.ready && prefs.showSynopsis && episode.overview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(episode.overview),
          ),
        if (entry != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              value: entry.progress,
              semanticsLabel: 'Episode progress',
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (entry != null && !entry.isCompleted && widget.onResume != null)
              FilledButton.icon(
                onPressed: () async {
                  await widget.onResume!(entry);
                  await _loadLocal();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume saved release'),
              ),
            if ((entry == null || entry.isCompleted) &&
                _series.ready &&
                prefs.autoSelect &&
                !future &&
                episode.aired != null)
              FilledButton.icon(
                onPressed: () => _find(media, episode.number),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play episode'),
              ),
            OutlinedButton.icon(
              onPressed: future
                  ? null
                  : () => Navigator.pop(
                      context,
                      ReleaseSearchSelection(
                        title: media.title,
                        kind: 'tv',
                        imdbId: media.imdbId,
                        season: _season,
                        episode: episode.number,
                        runtimeMinutes: episode.runtimeMinutes,
                      ),
                    ),
              icon: const Icon(Icons.search),
              label: const Text('Find episode releases'),
            ),
          ],
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < 560 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 26
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [thumbnail, const SizedBox(height: 12), info],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 200, child: thumbnail),
                    const SizedBox(width: 20),
                    Expanded(child: info),
                  ],
                ),
        ),
      ),
    );
  }
}
