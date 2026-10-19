import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'artwork.dart';
import 'metadata_service.dart';

/// Catalog facts remain distinct from discovery tags and filming geography.
class TitleInformation extends StatefulWidget {
  const TitleInformation({super.key, required this.media, this.artworkLoader});
  final MediaTitle media;
  final ArtworkLoader? artworkLoader;
  @override
  State<TitleInformation> createState() => _TitleInformationState();
}

class _TitleInformationState extends State<TitleInformation> {
  bool _allCast = false, _topics = false;
  Future<void> _source(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The source website could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final cast = media.cast.isNotEmpty
        ? media.cast
        : [
            for (final name
                in media.actors
                    .split(',')
                    .where((s) => s.trim().isNotEmpty)
                    .take(40))
              CastMember(name: name.trim()),
          ];
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Cast'),
        if (cast.isEmpty) const Text('Cast not available from this provider.'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final person in cast.take(_allCast ? 40 : 8))
              SizedBox(
                width: 150,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (person.photo.isNotEmpty) ...[
                          SizedBox(
                            width: 68,
                            child: TitleArtwork(
                              url: person.photo,
                              title: person.name,
                              loader: widget.artworkLoader,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          person.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (person.character.isNotEmpty)
                          Text(
                            person.character,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (cast.length > 8)
          TextButton(
            onPressed: () => setState(() => _allCast = !_allCast),
            child: Text(_allCast ? 'Show less cast' : 'Show more cast'),
          ),
        if (media.topics.isNotEmpty) ...[
          heading('Topics & keywords'),
          const Text('Provider tags may reveal story details.'),
          TextButton(
            onPressed: () => setState(() => _topics = !_topics),
            child: Text(_topics ? 'Hide topics' : 'Show topics'),
          ),
          if (_topics)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in media.topics) Chip(label: Text(topic)),
              ],
            ),
        ],
        if (media.filmingLocations.isNotEmpty ||
            media.narrativeLocations.isNotEmpty) ...[
          heading('Places'),
          if (media.filmingLocations.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.movie_outlined),
              title: const Text('Filmed in'),
              subtitle: Text(media.filmingLocations.join(' / ')),
            ),
          if (media.narrativeLocations.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Story setting'),
              subtitle: Text(media.narrativeLocations.join(' / ')),
            ),
          const Text('Location data via Wikidata; coverage may be incomplete.'),
          if (media.locationSource.isNotEmpty)
            TextButton(
              onPressed: () => _source(Uri.parse(media.locationSource)),
              child: const Text('View location sources on Wikidata'),
            ),
        ],
        heading('About this title'),
        for (final fact in {
          'Director': media.director,
          'Writer': media.writer,
          'Awards': media.awards,
          'Released': media.released,
          'Country of origin': media.country,
          'Original title languages': media.originalLanguage,
        }.entries)
          if (fact.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${fact.key}: ${fact.value}'),
            ),
        if (media.enrichmentSources.contains('TMDB')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.asset(
              'assets/branding/tmdb.png',
              width: 90,
              semanticLabel: 'TMDB logo',
            ),
          ),
          TextButton(
            onPressed: () => _source(Uri.https('www.themoviedb.org', '/')),
            child: const Text('Cast and keywords via TMDB'),
          ),
          const Text(
            'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          ),
        ],
      ],
    );
  }
}
