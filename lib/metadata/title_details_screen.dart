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
  });
  final ArtworkLoader? artworkLoader;
  final MetadataEnrichment? enrichment;
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
  Future<MediaTitle?> _loadDetails() async {
    final title = await widget.service.details(
      widget.apiKey,
      widget.title.imdbId,
    );
    if (title == null) return null;
    if (mounted) setState(() => _base = title);
    return _enrichment.enrich(title);
  }

  @override
  void dispose() {
    if (widget.enrichment == null) _enrichment.close();
    super.dispose();
  }

  late final _library = widget.libraryStore ?? TitleLibraryStore.shared;
  late final _watchlist = widget.watchlistStore ?? WatchlistStore();
  List<PlaybackHistoryEntry> _history = [];
  bool _saved = false, _tracked = false, _ready = false, _busy = false;
  String? _storageError;
  int _season = 1;
  Future<List<MediaEpisode>>? _episodes;
  bool _spoilers = false;
  @override
  void initState() {
    super.initState();
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
    ),
  );
  Future<List<MediaEpisode>> _loadSeason(MediaTitle media, int season) async {
    final episodes = await widget.service.season(
      widget.apiKey,
      media.imdbId,
      season,
    );
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
    return FutureBuilder<MediaTitle?>(
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
                    if (snapshot.hasError ||
                        (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data == null))
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.metadataFailed),
                          TextButton(
                            onPressed: () =>
                                setState(() => _details = _loadDetails()),
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
                              style: Theme.of(context).textTheme.headlineLarge,
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
                              padding: const EdgeInsets.symmetric(vertical: 20),
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
                                  onPressed: () => _find(media),
                                  icon: const Icon(Icons.search),
                                  label: Text(l.metadataFindReleases),
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
                    if (media.kind == 'series') ...[
                      const SizedBox(height: 24),
                      Text(
                        'Seasons & episodes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Text(
                        'Select a season to load its catalog. Releases have not been checked.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final season in [
                            0,
                            for (var i = 1; i <= (media.totalSeasons ?? 1); i++)
                              i,
                          ])
                            ChoiceChip(
                              label: Text(
                                season == 0 ? 'Specials' : 'Season $season',
                              ),
                              selected: _episodes != null && _season == season,
                              onSelected: (_) => setState(() {
                                _season = season;
                                _episodes = _loadSeason(media, season);
                              }),
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show episode titles (spoilers)'),
                        value: _spoilers,
                        onChanged: (v) => setState(() => _spoilers = v),
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
                                    onPressed: () => setState(
                                      () => _episodes = _loadSeason(
                                        media,
                                        _season,
                                      ),
                                    ),
                                    child: Text(l.retry),
                                  ),
                                ],
                              );
                            }
                            if (!episodes.hasData) {
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
                              ],
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _episodeRow(MediaTitle media, MediaEpisode episode) {
    final entry = _entry(episode.number);
    final future = episode.isFuture(DateUtils.dateOnly(DateTime.now()));
    final label =
        'S${_season.toString().padLeft(2, '0')} E${episode.number.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _spoilers ? '$label / ${episode.title}' : label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              [
                if (episode.aired != null)
                  episode.aired!.toIso8601String().split('T').first,
                if (entry?.isCompleted == true)
                  'Watched'
                else if (entry != null)
                  'In progress',
                if (future) 'Not aired' else 'Releases not checked',
              ].join(' / '),
            ),
            if (entry != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(value: entry.progress),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry != null &&
                    !entry.isCompleted &&
                    widget.onResume != null)
                  FilledButton.icon(
                    onPressed: () async {
                      await widget.onResume!(entry);
                      await _loadLocal();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume saved release'),
                  ),
                OutlinedButton.icon(
                  onPressed: future ? null : () => _find(media, episode.number),
                  icon: const Icon(Icons.search),
                  label: const Text('Find episode releases'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
