import '../metadata/metadata_service.dart';
import '../metadata/metadata_enrichment.dart';
import '../search/release_search_selection.dart';

/// Only catalog-confirmed neighbours; specials never silently join season one.
class EpisodeCatalog {
  EpisodeCatalog({
    required this.service,
    required this.enrichment,
    required this.apiKey,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final MetadataService service;
  final MetadataEnrichment enrichment;
  final String apiKey;
  final DateTime Function() now;

  Future<List<MediaEpisode>> season(MediaTitle media, int season) async {
    List<MediaEpisode>? base;
    try {
      base = await service.season(apiKey, media.imdbId, season);
    } catch (_) {}
    final episodes = await enrichment.seasonEpisodes(
      media,
      season,
      base ?? const [],
    );
    if (base == null && episodes.isEmpty) {
      throw const MetadataException('season');
    }
    return episodes;
  }

  Future<ReleaseSearchSelection> adjacent(
    String imdbId,
    int seasonNumber,
    int episodeNumber,
    int direction, {
    required bool autoPick,
  }) async {
    if (normalizeImdbId(imdbId) == null ||
        seasonNumber < 0 ||
        seasonNumber > 100 ||
        episodeNumber < 0 ||
        episodeNumber > 9999 ||
        ![-1, 1].contains(direction)) {
      throw const EpisodeNavigationException(
        'This playback has no confirmed episode identity. Open the series and select an episode first.',
      );
    }
    final media = await service.details(apiKey, imdbId);
    if (media == null || media.kind != 'series' || media.imdbId != imdbId) {
      throw const EpisodeNavigationException(
        'Series information is unavailable. Configure OMDb in Artwork & ratings, then retry.',
      );
    }
    var number = seasonNumber;
    var episodes = await season(media, number);
    if (!episodes.any((e) => e.number == episodeNumber)) {
      throw const EpisodeNavigationException(
        'The current episode is not in this catalog. Check its title match before navigating.',
      );
    }
    var candidates = episodes
        .where(
          (e) => direction > 0
              ? e.number > episodeNumber
              : e.number < episodeNumber,
        )
        .toList();
    if (candidates.isEmpty && number > 0) {
      final other = number + direction;
      if (other >= 1 &&
          media.totalSeasons != null &&
          other <= media.totalSeasons!) {
        number = other;
        episodes = await season(media, number);
        candidates = episodes;
      }
    }
    if (candidates.isEmpty) {
      throw EpisodeNavigationException(
        direction > 0
            ? 'No next episode is listed in the available catalog.'
            : 'No previous episode is listed in the available catalog.',
      );
    }
    candidates.sort((a, b) => a.number.compareTo(b.number));
    final target = direction > 0 ? candidates.first : candidates.last;
    final today = DateTime(now().year, now().month, now().day);
    if (target.aired == null || target.isFuture(today)) {
      throw const EpisodeNavigationException(
        'The adjacent episode has not aired or its air date is unknown. Current playback is unchanged.',
      );
    }
    return ReleaseSearchSelection(
      title: media.title,
      kind: 'tv',
      imdbId: imdbId,
      season: number,
      episode: target.number,
      runtimeMinutes: target.runtimeMinutes,
      autoPick: autoPick,
    );
  }
}

class EpisodeNavigationException implements Exception {
  const EpisodeNavigationException(this.message);
  final String message;
}
