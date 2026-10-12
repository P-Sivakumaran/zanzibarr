import '../search/release_search_selection.dart' show releaseTitleHint;
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
/// bölümünde göründüğü için burada tekrar önerilmez — bu kontrol,
/// sezon/bölüm numarası ayrıştırılamayan (ör. bölüm seçilmeden açılmış
/// sezon paketi) devam eden kayıtları da kapsar, yoksa aynı gösteri için
/// hem devam et hem de Sıradaki aynı anda görünebilir (code review bulgusu).
/// Grubun en yüksek sezon/bölümlü *tamamlanmış* kaydından bir sonraki bölüm
/// önerilir.
List<UpNextSuggestion> computeUpNext(List<PlaybackHistoryEntry> history) {
  final byShow = <String, List<PlaybackHistoryEntry>>{};
  for (final entry in history) {
    final imdbId = entry.imdbId;
    if (imdbId == null) continue;
    byShow.putIfAbsent(imdbId, () => []).add(entry);
  }

  final suggestions = <UpNextSuggestion>[];
  for (final group in byShow.entries) {
    if (group.value.any((e) => !e.isCompleted)) continue;

    final numbered = group.value.where(
      (e) => e.season != null && e.episode != null,
    );
    if (numbered.isEmpty) continue;

    final latest = numbered.reduce((a, b) {
      if (a.season! != b.season!) return a.season! > b.season! ? a : b;
      return a.episode! > b.episode! ? a : b;
    });

    suggestions.add(
      UpNextSuggestion(
        // Geçmişteki başlık oynatılan video dosyasının adıdır (çözünürlük/
        // grup etiketi dahil); bir sonraki bölüm sorgusuna olduğu gibi
        // eklenirse aramayı izlenmiş bölümün tam dosya adına kilitler
        // (code review bulgusu) — temiz gösteri adı çıkarılır.
        title: releaseTitleHint(latest.title),
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
