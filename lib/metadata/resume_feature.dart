import 'dart:async';
import 'title_resolver.dart';
import 'package:flutter/material.dart';
import '../player/playback_history.dart';
import '../player/gyuni_player_controls.dart' show formatPlayerDuration;
import 'artwork.dart';
import 'metadata_service.dart';
import 'metadata_screen.dart';
import 'metadata_visuals.dart';
import 'title_library.dart';

/// A real title view over the exact saved release. A filename is only a search
/// hint, never evidence of a movie identity, rating, artwork or episode catalog.
class ResumeFeature extends StatefulWidget {
  const ResumeFeature({
    super.key,
    required this.entry,
    this.title,
    required this.service,
    required this.settings,
    required this.library,
    required this.history,
    required this.onResume,
    required this.onDetails,
    required this.onMatched,
    this.artworkLoader,
  });
  final PlaybackHistoryEntry entry;
  final MediaTitle? title;
  final MetadataService service;
  final MetadataSettingsStore settings;
  final TitleLibraryStore library;
  final PlaybackHistoryStore history;
  final VoidCallback onResume;
  final ValueChanged<MediaTitle> onDetails;
  final Future<void> Function() onMatched;
  final ArtworkLoader? artworkLoader;
  @override
  State<ResumeFeature> createState() => _ResumeFeatureState();
}

class _ResumeFeatureState extends State<ResumeFeature> {
  late final _resolver = TitleResolver(widget.service, widget.settings);
  int _generation = 0;
  bool _automaticBusy = false;
  String? _attemptedIdentity;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _automatic());
  }

  @override
  void didUpdateWidget(ResumeFeature old) {
    super.didUpdateWidget(old);
    if (old.entry != widget.entry || old.title != widget.title) {
      _generation++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _automatic());
    }
  }

  Future<void> _automatic() async {
    if (!mounted || _automaticBusy) return;
    final saved = widget.title;
    if (saved != null &&
        (saved.plot.isNotEmpty ||
            saved.ratings.isNotEmpty ||
            saved.poster.isNotEmpty) &&
        !(saved.ratings.containsKey('IMDb') &&
            !saved.ratingCounts.containsKey('IMDb')) &&
        !(saved.fetchedAt != null &&
            DateTime.now().difference(saved.fetchedAt!) >
                const Duration(hours: 6))) {
      return;
    }
    final identity =
        '${widget.entry.nzbPath}:${widget.entry.entryKey}:${widget.entry.imdbId}';
    if (_attemptedIdentity == identity) return;
    _attemptedIdentity = identity;
    _automaticBusy = true;
    final generation = _generation;
    final expected = widget.entry;
    final hint = releaseHint(expected.title, series: expected.season != null);
    try {
      final media = await _resolver.resolve(
        title: hint.title,
        year: hint.year,
        kind: hint.kind,
        imdbId: expected.imdbId,
      );
      if (media == null ||
          !mounted ||
          generation != _generation ||
          (expected.season != null && media.kind != 'series')) {
        return;
      }
      await widget.library.save(media);
      if (!mounted || generation != _generation) return;
      if (expected.imdbId != media.imdbId) {
        await widget.history.setTitleIdentity(expected, media.imdbId);
      }
      if (mounted && generation == _generation) await widget.onMatched();
    } catch (_) {
      /* A missing key/provider never blocks Resume or correction. */
    } finally {
      _automaticBusy = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _resolver.close();
    super.dispose();
  }

  bool _busy = false;
  String? _error;
  Future<void> _match({bool choose = false}) async {
    if (_busy) return;
    _generation++;
    setState(() {
      _busy = true;
      _error = null;
    });
    final expected = widget.entry;
    try {
      var key = await widget.settings.load();
      var id = normalizeImdbId(expected.imdbId ?? '');
      String? selectedKind;
      if (choose || id == null || key.isEmpty) {
        if (!mounted) return;
        final candidate = await Navigator.of(context).push<MediaTitle>(
          MaterialPageRoute(
            builder: (_) => MetadataScreen(
              service: widget.service,
              store: widget.settings,
              selectTitleOnly: true,
              initialQuery: choose || id == null
                  ? _searchHint(expected.title)
                  : id,
              initialKind: expected.season != null ? 'series' : 'movie',
            ),
          ),
        );
        if (candidate == null || !mounted) return;
        id = candidate.imdbId;
        selectedKind = candidate.kind;
        key = await widget.settings.load();
      }
      if (key.isEmpty) throw const MetadataException('key');
      final media = await widget.service.details(key, id);
      if (!mounted) return;
      if (media == null ||
          media.imdbId != id ||
          (selectedKind != null && media.kind != selectedKind) ||
          (expected.season != null && media.kind != 'series')) {
        throw const MetadataException('response');
      }
      // Save public metadata first; on a history failure playback data stays intact.
      await widget.library.save(media);
      if (expected.imdbId != id) {
        await widget.history.setTitleIdentity(expected, id);
      }
      if (mounted) await widget.onMatched();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is LibraryFull
              ? 'Your library is full. Remove a saved title before adding this match.'
              : 'Title details could not be loaded or saved. Playback is still available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _searchHint(String release) {
    final name = release.split(RegExp(r'[/\\]')).last;
    return name
        .replaceAll(RegExp(r'\.(?:nzb|mkv|mp4)$', caseSensitive: false), '')
        .split(
          RegExp(
            r'(?:[ ._-]S[0-9]{1,2}E[0-9]{1,3}|[ ._-](?:19|20)[0-9]{2}|[ ._-](?:720p|1080p|2160p|WEB-DL|BluRay))',
            caseSensitive: false,
          ),
        )
        .first
        .replaceAll(RegExp(r'[._]+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.title;
    final entry = widget.entry;
    final remaining = Duration(
      seconds: (entry.durationSeconds - entry.positionSeconds)
          .clamp(0, double.maxFinite)
          .round(),
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up where you left off',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        Text(
          media?.title ?? 'Saved release',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (media != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              media.year,
              media.certification,
              media.runtime,
              if (entry.season != null)
                'Season ${entry.season} / Episode ${entry.episode ?? "?"}',
            ].where((v) => v.isNotEmpty).join(' / '),
          ),
        ],
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (media != null) ...[
          if (media.genre.isNotEmpty)
            Text(media.genre, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Text(
            media.plot.isEmpty
                ? 'A synopsis is not available from this provider.'
                : media.plot,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          RatingMeters(media: media),
          if (media.actors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Starring ${media.actors}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final source in ['IMDb', 'Rotten Tomatoes', 'Metacritic'])
                if (!media.ratings.containsKey(source))
                  Text(
                    '$source: unavailable',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            ],
          ),
        ] else
          Text(
            'Title artwork and ratings load automatically when metadata access is configured. Use Rematch title if a correction is needed.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: entry.progress),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            semanticsLabel: 'Viewing progress',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.durationSeconds > 0
              ? '${formatPlayerDuration(entry.position)} watched / ${formatPlayerDuration(remaining)} remaining'
              : '${formatPlayerDuration(entry.position)} watched',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: widget.onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
            if (media != null)
              OutlinedButton.icon(
                onPressed: () => widget.onDetails(media),
                icon: const Icon(Icons.info_outline),
                label: const Text('Title details'),
              ),
            TextButton.icon(
              onPressed: _busy ? null : () => _match(choose: true),
              icon: const Icon(Icons.image_search),
              label: Text(_busy ? 'Loading title details...' : 'Rematch title'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Release information',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(entry.title),
              ),
            ],
          ),
        ),
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final poster = TitleArtwork(
              url: media?.poster ?? '',
              title: media?.title ?? 'Saved release',
              loader: widget.artworkLoader,
            );
            if (constraints.maxWidth < 700 ||
                MediaQuery.textScalerOf(context).scale(16) > 26) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 88, child: poster),
                      const SizedBox(width: 16),
                      Expanded(child: heading),
                    ],
                  ),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 230, child: poster),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, details],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
