import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/playback_history.dart';
import 'package:zanzibarr/player/up_next.dart';

PlaybackHistoryEntry _entry({
  required String path,
  required String imdbId,
  required int season,
  required int episode,
  bool completed = true,
  int updatedAt = 1000,
  String title = 'show.mkv',
}) => PlaybackHistoryEntry(
  nzbPath: path,
  title: title,
  positionSeconds: completed ? 5900 : 100,
  durationSeconds: 6000,
  updatedAtMs: updatedAt,
  imdbId: imdbId,
  season: season,
  episode: episode,
);

void main() {
  test('tamamlanmış tek bölüm bir sonraki bölümü önerir', () {
    final suggestions = computeUpNext([
      _entry(path: '/s1e1.nzb', imdbId: 'tt1', season: 1, episode: 1),
    ]);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.season, 1);
    expect(suggestions.single.episode, 2);
    expect(suggestions.single.imdbId, 'tt1');
  });

  test('devam eden bölüm varsa aynı gösteri için öneri yapılmaz', () {
    final suggestions = computeUpNext([
      _entry(
        path: '/s1e1.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        completed: true,
      ),
      _entry(
        path: '/s1e2.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 2,
        completed: false,
      ),
    ]);

    expect(suggestions, isEmpty);
  });

  test('imdbId veya sezon/bölüm olmayan kayıtlar yok sayılır', () {
    final suggestions = computeUpNext([
      const PlaybackHistoryEntry(
        nzbPath: '/free-text.nzb',
        title: 'random.mkv',
        positionSeconds: 5900,
        durationSeconds: 6000,
        updatedAtMs: 1000,
      ),
    ]);

    expect(suggestions, isEmpty);
  });

  test('en yüksek sezon/bölümlü tamamlanmış kayıt esas alınır', () {
    final suggestions = computeUpNext([
      _entry(
        path: '/s1e1.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        updatedAt: 1,
      ),
      _entry(
        path: '/s1e3.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 3,
        updatedAt: 3,
      ),
      _entry(
        path: '/s1e2.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 2,
        updatedAt: 2,
      ),
    ]);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.episode, 4);
  });

  test('birden fazla gösteri en son izlenen önce sıralanır', () {
    final suggestions = computeUpNext([
      _entry(
        path: '/a.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        updatedAt: 1,
      ),
      _entry(
        path: '/b.nzb',
        imdbId: 'tt2',
        season: 1,
        episode: 1,
        updatedAt: 2,
      ),
    ]);

    expect(suggestions, hasLength(2));
    expect(suggestions.first.imdbId, 'tt2');
    expect(suggestions.last.imdbId, 'tt1');
  });

  test('farklı sezonlar arasında en yüksek sezon kazanır', () {
    final suggestions = computeUpNext([
      _entry(
        path: '/s1e5.nzb',
        imdbId: 'tt1',
        season: 1,
        episode: 5,
        updatedAt: 1,
      ),
      _entry(
        path: '/s2e1.nzb',
        imdbId: 'tt1',
        season: 2,
        episode: 1,
        updatedAt: 2,
      ),
    ]);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.season, 2);
    expect(suggestions.single.episode, 2);
  });
}
