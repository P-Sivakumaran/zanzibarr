import '../metadata/metadata_service.dart';
import '../src/rust/api/search.dart';

/// Canonical identity is separate from the editable free-text query. Editing
/// that query clears the selection, so an old ID cannot constrain a new title.
class ReleaseSearchSelection {
  const ReleaseSearchSelection({
    required this.title,
    required this.kind,
    this.imdbId,
    this.tvdbId,
    this.year,
    this.season,
    this.episode,
    this.autoPick = false,
    this.runtimeMinutes,
  });
  final String title;
  final String kind; // movie / tv
  final String? imdbId;
  final String? tvdbId;
  final int? year;
  final int? season;
  final int? episode;
  final bool autoPick;
  final int? runtimeMinutes;

  factory ReleaseSearchSelection.fromMedia(MediaTitle media) =>
      ReleaseSearchSelection(
        title: media.title,
        kind: media.kind == 'series' ? 'tv' : 'movie',
        imdbId: media.imdbId,
        year: int.tryParse(media.year.split(RegExp(r'\D')).first),
      );

  String get fallbackQuery => [
    title.trim(),
    if (kind == 'movie' && year != null) '$year',
    if (kind == 'tv' && season != null)
      'S${season.toString().padLeft(2, '0')}${episode == null ? '' : 'E${episode.toString().padLeft(2, '0')}'}',
  ].where((part) => part.isNotEmpty).join(' ');

  StructuredSearchDto toDto(List<String> params) => StructuredSearchDto(
    kind: kind,
    imdbId: imdbId,
    tvdbId: tvdbId,
    season: season,
    episode: episode,
    supportedParams: params,
  );
}

/// This is only a lookup hint. The user confirms a title/year before a
/// metadata identity is ever used to constrain release search.
String releaseTitleHint(String release) {
  final boundary = RegExp(
    r'(?:[ ._\-])(?:19\d{2}|20\d{2}|S\d{1,3}E\d{1,3}|S\d{1,3})(?:[ ._\-]|$)',
    caseSensitive: false,
  ).firstMatch(release);
  return (boundary == null ? release : release.substring(0, boundary.start))
      .replaceAll(RegExp(r'[._]+'), ' ')
      .trim();
}
