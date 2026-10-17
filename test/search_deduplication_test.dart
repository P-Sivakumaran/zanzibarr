import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/search/search_deduplication.dart';
import 'package:zanzibarr/src/rust/api/search.dart';

SearchItemDto item(String title, String url, int? size) => SearchItemDto(
  title: title,
  nzbUrl: url,
  sizeBytes: size == null ? null : BigInt.from(size),
  badges: const [],
  mediaKind: 'other',
  sourceIndexer: 'test',
);

// Original pairwise algorithm serves as a behavioral oracle.
List<SearchItemDto> reference(Iterable<SearchItemDto> items) {
  String key(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[\s._\-\[\]()]+'), '');
  final kept = <SearchItemDto>[];
  for (final item in items) {
    if (!kept.any((existing) {
      if (existing.nzbUrl == item.nzbUrl) return true;
      if (key(existing.title) != key(item.title)) return false;
      final a = existing.sizeBytes;
      final b = item.sizeBytes;
      if (a == null || b == null) return a == b;
      final high = a > b ? a : b;
      return (a - b).abs() <= high ~/ BigInt.from(100);
    })) {
      kept.add(item);
    }
  }
  return kept;
}

void main() {
  test('preserves first source, normalization and one-percent boundary', () {
    final a = item('Show.Name-[S01E01]', 'a', 990);
    final boundary = item('show name (s01e01)', 'b', 1000);
    final distinct = item('SHOW_NAME_S01E01', 'c', 1001);
    final sameUrl = item('different title', 'a', null);
    expect(uniqueSearchItems([a, boundary, distinct, sameUrl]), [a, distinct]);
  });
  test('unknown and zero sizes remain distinct', () {
    final unknown = item('show', 'a', null);
    final zero = item('show', 'b', 0);
    expect(
      uniqueSearchItems([
        unknown,
        zero,
        item('show', 'c', null),
        item('show', 'd', 0),
      ]),
      [unknown, zero],
    );
  });
  test('discarded matches do not suppress later releases by URL or size', () {
    final a = item('show', 'a', 10000);
    final discarded = item('show', 'b', 10100);
    final c = item('show', 'c', 10200);
    final reusedUrl = item('other', 'b', 10000);
    expect(uniqueSearchItems([a, discarded, c, reusedUrl]), [a, c, reusedUrl]);
  });
  test('matches pairwise behavior across deterministic mixed pages', () {
    final random = Random(42);
    for (var run = 0; run < 40; run++) {
      final items = List.generate(
        150,
        (i) => item(
          ['Show.Name', 'show name', 'Other', 'Third'][random.nextInt(4)],
          'url-${random.nextInt(100)}',
          random.nextInt(5) == 0 ? null : 9900 + random.nextInt(400),
        ),
      );
      expect(uniqueSearchItems(items), reference(items));
    }
  });
}
