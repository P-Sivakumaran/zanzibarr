import 'playback_history.dart';

/// Tamamlanmış bir bölümden türetilen "sıradaki bölüm" önerisi.
///
/// Ağ çağrısı yapılmaz: yalnızca geçmişteki kayıtlardan çıkarılır. Sezon
/// içindeki bölüm numarası varsayımla bir artırılır (toplam bölüm sayısı
/// bilinmediği için sezon geçişi tespit edilemez — bu bilinen bir sınırdır).
class UpNextSuggestion {
  const UpNextSuggestion({
    required this.title,
    required this.imdbId,
    required this.season,
    required this.episode,
    required this.lastWatchedAtMs,
  });

  final String title;
  final String imdbId;
  final int season;
  final int episode;
  final int lastWatchedAtMs;
}

/// [history] içindeki kayıtları `imdbId`'ye göre gruplar; bir grupta devam
/// eden (tamamlanmamış) bir kayıt varsa o gösteri zaten "İzlemeye devam et"
/// bölümünde göründüğü için burada tekrar önerilmez. Grubun en yüksek
/// sezon/bölümlü kaydı tamamlanmışsa, bir sonraki bölüm önerilir.
List<UpNextSuggestion> computeUpNext(List<PlaybackHistoryEntry> history) {
  final byShow = <String, List<PlaybackHistoryEntry>>{};
  for (final entry in history) {
    final imdbId = entry.imdbId;
    if (imdbId == null || entry.season == null || entry.episode == null) {
      continue;
    }
    byShow.putIfAbsent(imdbId, () => []).add(entry);
  }

  final suggestions = <UpNextSuggestion>[];
  for (final group in byShow.entries) {
    if (group.value.any((e) => !e.isCompleted)) continue;

    final latest = group.value.reduce((a, b) {
      if (a.season! != b.season!) return a.season! > b.season! ? a : b;
      return a.episode! > b.episode! ? a : b;
    });

    suggestions.add(
      UpNextSuggestion(
        title: latest.title,
        imdbId: group.key,
        season: latest.season!,
        episode: latest.episode! + 1,
        lastWatchedAtMs: latest.updatedAtMs,
      ),
    );
  }

  suggestions.sort((a, b) => b.lastWatchedAtMs.compareTo(a.lastWatchedAtMs));
  return suggestions;
}
