// Review-only composition. Never imported by a production entrypoint.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../main.dart' show HomeScreen;
import '../metadata/artwork.dart';
import '../metadata/library_screen.dart';
import '../metadata/metadata_service.dart';
import '../metadata/metadata_enrichment.dart';
import '../metadata/title_details_screen.dart';
import '../metadata/title_library.dart';
import '../player/media_preferences.dart';
import '../player/playback_history.dart';
import '../player/series_preferences.dart';
import '../player/watchlist.dart';
import '../settings/settings_home.dart';
import '../update/update_service.dart';

const reviewTitle = MediaTitle(
  imdbId: 'tt1234567',
  title: 'The Quiet Coast',
  kind: 'series',
  year: '2026',
  genre: 'Drama / Mystery',
  runtime: '48 min',
  certification: 'TV-14',
  plot: 'A lighthouse keeper returns to the coast where she grew up.',
  poster: 'quiet-coast',
  totalSeasons: 2,
  ratings: {'IMDb': '8.2/10', 'Rotten Tomatoes': '87%', 'Metacritic': '76/100'},
  ratingCounts: {'IMDb': 123456, 'Rotten Tomatoes': 240, 'Metacritic': 45},
  provider: 'Sample data',
);
const reviewTitles = [
  reviewTitle,
  MediaTitle(
    imdbId: 'tt1234568',
    title: 'The Last Orchard',
    kind: 'movie',
    year: '2025',
    poster: 'last-orchard',
  ),
  MediaTitle(
    imdbId: 'tt1234569',
    title: 'Blue Hours',
    kind: 'movie',
    year: '2024',
    poster: 'blue-hours',
  ),
  MediaTitle(
    imdbId: 'tt1234570',
    title: 'A Place Between',
    kind: 'movie',
    year: '2026',
    poster: 'place-between',
  ),
];
const reviewEntry = PlaybackHistoryEntry(
  nzbPath: '/sample/coast.nzb',
  entryKey: 'sample-episode',
  title: 'The.Quiet.Coast.S01E03.1080p.WEB-DL.mkv',
  imdbId: 'tt1234567',
  season: 1,
  episode: 3,
  positionSeconds: 1800,
  durationSeconds: 2880,
  updatedAtMs: 1,
);

class ReviewStorage implements PlayerPreferenceStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Library extends TitleLibraryStore {
  @override
  Future<List<MediaTitle>> load() async => reviewTitles;
}

class _History extends PlaybackHistoryStore {
  @override
  Future<List<PlaybackHistoryEntry>> load() async => [reviewEntry];
}

class _Watchlist extends WatchlistStore {
  @override
  Future<List<WatchlistEntry>> load() async => [];
  @override
  Future<bool> isTracked(String id) async => false;
}

class _Updates extends UpdateService {
  @override
  Future<ReleaseInfo?> checkForUpdate({bool ignoreSkipped = false}) async =>
      null;
}

class _Settings extends MetadataSettingsStore {
  @override
  Future<String> load() async => '';
}

class _Catalog extends MetadataService {
  @override
  Future<MediaTitle?> details(String key, String id) async => reviewTitle;
  @override
  Future<List<MediaEpisode>> season(String key, String id, int season) async =>
      [
        for (var n = 1; n <= 5; n++)
          MediaEpisode(
            number: n,
            title: [
              'Low tide',
              'Homecoming',
              'The lighthouse',
              'Blue water',
              'The crossing',
            ][n - 1],
            aired: DateTime(2026, 1, n),
            still: 'quiet-coast',
            runtimeMinutes: 48,
          ),
      ];
}

class _Enrichment extends MetadataEnrichment {
  @override
  Future<MediaTitle> enrich(MediaTitle title) async => title;
  @override
  Future<List<MediaEpisode>> seasonEpisodes(
    MediaTitle title,
    int season,
    List<MediaEpisode> base,
  ) async => base;
}

class ReviewArtwork extends ArtworkLoader {
  ReviewArtwork(this.images);
  final Map<String, Uint8List> images;
  @override
  Future<Uint8List?> load(String url) async => images[url];
}

/// Renders production widgets, with all data loads replaced by local fixtures.
/// The caller must disable interaction with this content: navigation and form
/// actions are intentionally not part of the sample-data review.
class ReviewFixture {
  ReviewFixture(Map<String, Uint8List> images) : art = ReviewArtwork(images);
  final ReviewArtwork art;
  final _catalog = _Catalog();
  final _enrichment = _Enrichment();
  final _library = _Library();
  final _watchlist = _Watchlist();
  final _history = _History();
  final _series = SeriesPreferences(storage: ReviewStorage());
  final _artworkPreferences = ArtworkPreferences(
    storage: ReviewStorage()..values['metadata.artwork.enabled'] = 'true',
  );
  Widget screen(int index) => switch (index) {
    1 => LibraryScreen(
      store: _library,
      watchlistStore: _watchlist,
      artworkLoader: art,
      artworkPreferences: _artworkPreferences,
      onOpen: (_) async {},
      onPlaylists: () {},
    ),
    2 => TitleDetailsScreen(
      title: reviewTitle,
      service: _catalog,
      apiKey: '',
      enrichment: _enrichment,
      libraryStore: _library,
      historyStore: _history,
      watchlistStore: _watchlist,
      seriesPreferences: _series,
      artworkLoader: art,
    ),
    3 => const SettingsHomeScreen(),
    _ => HomeScreen(
      historyStore: _history,
      titleLibraryStore: _library,
      watchlistStore: _watchlist,
      metadataService: _catalog,
      metadataSettings: _Settings(),
      updateService: _Updates(),
      artworkLoader: art,
    ),
  };
  void dispose() {
    art.close();
    _catalog.close();
    _enrichment.close();
    _series.dispose();
    _artworkPreferences.dispose();
  }
}
