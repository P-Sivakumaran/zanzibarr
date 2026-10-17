import '../src/rust/api/search.dart';

final _titleSeparators = RegExp(r'[\s._\-\[\]()]+');
final _sizeToleranceDivisor = BigInt.from(100);

/// Keep the first matching release, preserving source priority and input order.
/// Only retained releases participate: approximate size matching is not transitive.
List<SearchItemDto> uniqueSearchItems(Iterable<SearchItemDto> items) {
  final urls = <String>{};
  final byTitle = <String, List<BigInt?>>{};
  final kept = <SearchItemDto>[];
  for (final item in items) {
    if (urls.contains(item.nzbUrl)) continue;
    final key = item.title.toLowerCase().replaceAll(_titleSeparators, '');
    final sizes = byTitle[key];
    final size = item.sizeBytes;
    final duplicate =
        sizes?.any((existing) {
          if (existing == null || size == null) return existing == size;
          final high = existing > size ? existing : size;
          return (existing - size).abs() <= high ~/ _sizeToleranceDivisor;
        }) ??
        false;
    if (duplicate) continue;
    urls.add(item.nzbUrl);
    (byTitle[key] ??= []).add(size);
    kept.add(item);
  }
  return kept;
}
