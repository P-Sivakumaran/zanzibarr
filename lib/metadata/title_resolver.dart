import 'dart:async';
import 'dart:collection';
import 'metadata_service.dart';

String normalizedTitle(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
int? titleYear(String value) => int.tryParse(
  RegExp(r'^(?:18|19|20|21|22)[0-9]{2}').firstMatch(value)?.group(0) ?? '',
);
({String title, int? year, String kind}) releaseHint(
  String release, {
  bool series = false,
}) {
  final name = release
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'\.(?:nzb|mkv|mp4)$', caseSensitive: false), '');
  final isSeries =
      series ||
      RegExp(r'S[0-9]{1,2}E[0-9]{1,3}', caseSensitive: false).hasMatch(name);
  final marker = RegExp(
    r'(?:[ ._-]S[0-9]{1,2}E[0-9]{1,3}|[ ._-](?:18|19|20|21)[0-9]{2}|[ ._-](?:720p|1080p|2160p|WEB-DL|BluRay))',
    caseSensitive: false,
  ).firstMatch(name);
  final year = RegExp(
    r'(?:^|[ ._(])((?:18|19|20|21)[0-9]{2})(?=[ ._)_-]|$)',
  ).allMatches(name).where((match) => match.start > 0).firstOrNull;
  return (
    title: (marker == null ? name : name.substring(0, marker.start))
        .replaceAll(RegExp(r'[._]+'), ' ')
        .trim(),
    // Episode release years do not establish a series' premiere year.
    year: isSeries ? null : int.tryParse(year?.group(1) ?? ''),
    kind: isSeries ? 'series' : 'movie',
  );
}

/// Resolve only unique exact title/type/year matches. Two requests may run at
/// once, with at most 32 waiting; identical pending jobs coalesce. No AI IDs.
class TitleResolver {
  TitleResolver(this.service, this.settings);
  final MetadataService service;
  final MetadataSettingsStore settings;
  final _jobs = Queue<void Function()>();
  final _pending = <String, Future<MediaTitle?>>{};
  int _active = 0;
  bool _closed = false;
  Future<MediaTitle?> resolve({
    required String title,
    required String kind,
    int? year,
    String? imdbId,
  }) {
    if (_closed) return Future.value(null);
    final identity = '$imdbId:$kind:$year:${normalizedTitle(title)}';
    final old = _pending[identity];
    if (old != null) return old;
    if (_jobs.length >= 32) return Future.value(null);
    final result = Completer<MediaTitle?>();
    _pending[identity] = result.future;
    _jobs.add(() async {
      try {
        result.complete(
          _closed ? null : await _resolve(title, kind, year, imdbId),
        );
      } catch (_) {
        result.complete(null);
      } finally {
        _pending.remove(identity);
        _active--;
        _drain();
      }
    });
    _drain();
    return result.future;
  }

  void _drain() {
    while (_active < 2 && _jobs.isNotEmpty) {
      _active++;
      _jobs.removeFirst()();
    }
  }

  Future<MediaTitle?> _resolve(
    String title,
    String kind,
    int? year,
    String? id,
  ) async {
    final key = await settings.load();
    if (key.isEmpty || _closed) return null;
    final known = normalizeImdbId(id ?? '');
    if (known != null) {
      final details = await service.details(key, known);
      return !_closed && details?.imdbId == known ? details : null;
    }
    if (normalizedTitle(title).isEmpty) return null;
    final page = await service.search(key, title, kind: kind, year: year);
    if (_closed || page.hasMore) return null;
    final matches = <String, MediaTitle>{
      for (final item in page.titles)
        if (item.kind == kind &&
            normalizedTitle(item.title) == normalizedTitle(title) &&
            (year == null || titleYear(item.year) == year))
          item.imdbId: item,
    };
    if (matches.length != 1) return null;
    final candidate = matches.values.single;
    final details = await service.details(key, candidate.imdbId);
    if (_closed ||
        details == null ||
        details.imdbId != candidate.imdbId ||
        details.kind != kind ||
        normalizedTitle(details.title) != normalizedTitle(title) ||
        (year != null && titleYear(details.year) != year)) {
      return null;
    }
    return details;
  }

  void close() {
    _closed = true;
    _drain();
  }
}
