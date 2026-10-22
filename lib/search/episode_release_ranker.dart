import 'dart:math' as math;
import '../player/series_preferences.dart';
import '../src/rust/api/search.dart';
import 'release_search_selection.dart';

class EpisodeReleaseChoice {
  const EpisodeReleaseChoice(this.item, this.height, this.mbps);
  final SearchItemDto item;
  final int height;
  final double mbps;
  String get explanation =>
      '${height}p / estimated ${mbps.toStringAsFixed(1)} Mbps average. Size/runtime estimate; availability and decoding are unverified.';
}

String _identity(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

bool isExactEpisode(SearchItemDto item, ReleaseSearchSelection target) {
  if (item.mediaKind != 'tv' ||
      target.kind != 'tv' ||
      target.season == null ||
      target.episode == null) {
    return false;
  }
  if (item.season != null && item.season != target.season ||
      item.episode != null && item.episode != target.episode) {
    return false;
  }
  if (item.imdbId != null && item.imdbId != target.imdbId) return false;
  final matches = RegExp(
    r'(?:^|[ ._\-])(?:S(\d{1,3})E(\d{1,4})|(\d{1,3})x(\d{1,4}))(?=$|[ ._\-])',
    caseSensitive: false,
  ).allMatches(item.title).toList();
  if (matches.length != 1) return false;
  final match = matches.single;
  if (int.parse(match[1] ?? match[3]!) != target.season ||
      int.parse(match[2] ?? match[4]!) != target.episode) {
    return false;
  }
  // Do not silently choose packs, multi-episode cuts, samples or trailers.
  if (RegExp(
    r'(?:S\d+E\d+(?:E\d+|[- ]E?\d+))|(?:\d+x\d+(?:x\d+|[- ](?:\d+x)?\d+))|\b(?:complete|pack|sample|trailer)\b',
    caseSensitive: false,
  ).hasMatch(item.title)) {
    return false;
  }
  final name = _identity(item.title.substring(0, match.start));
  final expectedName = _identity(target.title);
  return item.imdbId == target.imdbId && target.imdbId != null ||
      expectedName.isNotEmpty && name == expectedName;
}

List<EpisodeReleaseChoice> rankEpisodeReleases(
  List<SearchItemDto> items,
  ReleaseSearchSelection target,
  SeriesOptions options,
) {
  final minutes = target.runtimeMinutes;
  if (minutes == null || minutes <= 0 || minutes > 600) return [];
  final result = <EpisodeReleaseChoice>[];
  for (final item in items) {
    if (!isExactEpisode(item, target) ||
        item.sizeBytes == null ||
        item.sizeBytes! <= BigInt.zero ||
        item.sizeBytes!.bitLength > 53) {
      continue;
    }
    final text = '${item.title} ${item.badges.join(' ')}';
    final match = RegExp(
      r'\b(480|720|1080|2160)p\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) continue;
    final height = int.parse(match[1]!);
    // Conservative compatible preference; uncertain codecs remain manual choices.
    if (height > options.maxHeight ||
        RegExp(
          r'\b(?:AV1|DV|DoVi|Dolby[ .]?Vision)\b',
          caseSensitive: false,
        ).hasMatch(text) ||
        !RegExp(
          r'\b(?:x264|h[ .]?264|AVC)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      continue;
    }
    final mbps = item.sizeBytes!.toDouble() * 8 / (minutes * 60) / 1000000;
    final minimum = height >= 1080 ? 1.0 : .4;
    if (!mbps.isFinite ||
        mbps < minimum ||
        mbps > options.connectionMbps * .6) {
      continue;
    }
    result.add(EpisodeReleaseChoice(item, height, mbps));
  }
  result.sort((a, b) {
    final quality = b.height.compareTo(a.height);
    if (quality != 0) return quality;
    // A heuristic quality/size balance, not a measurement of encode quality.
    final preferred = math.min(options.connectionMbps * .6, switch (a.height) {
      2160 => 20.0,
      1080 => 6.0,
      720 => 3.0,
      _ => 1.5,
    });
    return (a.mbps - preferred).abs().compareTo((b.mbps - preferred).abs());
  });
  return result;
}

class SelectedEpisodeRelease {
  const SelectedEpisodeRelease({
    required this.path,
    required this.selection,
    required this.sourceId,
    required this.nzbUrl,
  });
  final String path, nzbUrl;
  final String? sourceId;
  final ReleaseSearchSelection selection;
}
