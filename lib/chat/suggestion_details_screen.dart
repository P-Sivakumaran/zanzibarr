import 'package:flutter/material.dart';
import '../metadata/metadata_service.dart';
import '../metadata/metadata_screen.dart';
import '../metadata/title_details_screen.dart';
import '../metadata/artwork.dart';
import 'film_playlist.dart';
import 'suggestion_metadata.dart';

/// Push immediately; resolve inside the route so a network request never blocks the card.
class SuggestionDetailsScreen extends StatefulWidget {
  const SuggestionDetailsScreen({
    super.key,
    required this.film,
    required this.metadata,
    required this.onRematch,
    this.artworkLoader,
  });
  final FilmSuggestion film;
  final SuggestionMetadata metadata;
  final Future<void> Function() onRematch;
  final ArtworkLoader? artworkLoader;
  @override
  State<SuggestionDetailsScreen> createState() =>
      _SuggestionDetailsScreenState();
}

class _SuggestionDetailsScreenState extends State<SuggestionDetailsScreen> {
  late Future<(MediaTitle?, String)> _pending = _load();
  @override
  void initState() {
    super.initState();
    widget.metadata.addListener(_metadataChanged);
  }

  void _metadataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.metadata.removeListener(_metadataChanged);
    super.dispose();
  }

  Future<(MediaTitle?, String)> _load() async {
    String key;
    try {
      key = await widget.metadata.settings.load();
      await widget.metadata.enrich(widget.film);
    } catch (_) {
      return (widget.metadata.forFilm(widget.film), '');
    }
    return (widget.metadata.forFilm(widget.film), key);
  }

  void _retry() {
    widget.metadata.resetAttempts();
    setState(() => _pending = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(MediaTitle?, String)>(
    future: _pending,
    builder: (context, snapshot) {
      final media = snapshot.data == null
          ? null
          : widget.metadata.forFilm(widget.film) ?? snapshot.data?.$1;
      if (media != null) {
        return TitleDetailsScreen(
          key: ValueKey(media.imdbId),
          title: media,
          service: widget.metadata.service,
          apiKey: snapshot.data!.$2,
          artworkLoader: widget.artworkLoader,
        );
      }
      final loading =
          snapshot.connectionState != ConnectionState.done ||
          widget.metadata.isLoading(widget.film);
      return Scaffold(
        appBar: AppBar(title: Text(widget.film.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.film.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (widget.film.year != null)
                Text('${widget.film.year} / ${widget.film.kind.label}'),
              const SizedBox(height: 16),
              if (loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Text('Loading title details...'),
              ] else ...[
                const Text(
                  'Title details are not available yet. Your suggestion is still saved; configure metadata or correct an ambiguous match.',
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _retry,
                      child: const Text('Retry details'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MetadataScreen(
                              service: widget.metadata.service,
                              store: widget.metadata.settings,
                            ),
                          ),
                        );
                        if (mounted) _retry();
                      },
                      child: const Text('Metadata settings'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.onRematch();
                        if (mounted) _retry();
                      },
                      child: const Text('Rematch title'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
