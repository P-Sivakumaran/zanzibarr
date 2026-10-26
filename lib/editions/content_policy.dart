/// Classification authority is explicit: strings from AI, indexers, saved
/// title objects and user input cannot create admission evidence.
enum ContentDecision { allowed, blocked, unclassified, verificationFailed }

enum ClassificationSystem { usMpa, usTv, australianClassification }

class ClassificationEvidence {
  const ClassificationEvidence({
    required this.canonicalId,
    required this.system,
    required this.rating,
    required this.validUntil,
    required this.authorityVerified,
    this.conflicting = false,
  });

  final String canonicalId, rating;
  final ClassificationSystem system;
  final DateTime validUntil;
  final bool authorityVerified, conflicting;
}

/// Pure policy, independent of widgets, networking or a mutable preference.
/// Evidence must come from a trusted adapter; no such production adapter is
/// assumed from OMDb's regionless Rated field.
abstract final class CleanContentPolicy {
  static ContentDecision evaluate(
    String canonicalId,
    List<ClassificationEvidence> evidence, {
    required DateTime now,
    bool verificationFailed = false,
  }) {
    if (verificationFailed) return ContentDecision.verificationFailed;
    if (!RegExp(r'^tt[0-9]{7,10}$').hasMatch(canonicalId) || evidence.isEmpty) {
      return ContentDecision.unclassified;
    }
    var allowed = false;
    for (final record in evidence) {
      if (!record.authorityVerified ||
          record.canonicalId != canonicalId ||
          !record.validUntil.isAfter(now) ||
          record.conflicting) {
        return ContentDecision.verificationFailed;
      }
      final approved = switch (record.system) {
        ClassificationSystem.usMpa => const {'G', 'PG'},
        ClassificationSystem.usTv => const {'TV-Y', 'TV-Y7', 'TV-G', 'TV-PG'},
        ClassificationSystem.australianClassification => const {'G', 'PG'},
      };
      final mature = switch (record.system) {
        ClassificationSystem.usMpa => const {'PG-13', 'R', 'NC-17'},
        ClassificationSystem.usTv => const {'TV-14', 'TV-MA'},
        ClassificationSystem.australianClassification => const {
          'M',
          'MA 15+',
          'R 18+',
          'X 18+',
          'RC',
        },
      };
      if (mature.contains(record.rating)) return ContentDecision.blocked;
      if (!approved.contains(record.rating)) {
        return ContentDecision.unclassified;
      }
      allowed = true;
    }
    return allowed ? ContentDecision.allowed : ContentDecision.unclassified;
  }

  /// An allowed title rating is not evidence about arbitrary NZB/media bytes.
  /// Playback requires a separately reviewed content-provenance implementation.
  static bool get arbitraryMediaAllowed => false;
}
