import 'metadata_service.dart';

/// Overview copy is built from catalog facts, never from a plot excerpt.
/// Truncating a synopsis cannot make its revelations safe.
String filmBlurb(MediaTitle title) {
  final genres = title.genre
      .split(RegExp(r'[,/]'))
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty && s.length <= 24)
      .take(3)
      .join(', ');
  final kind = title.kind == 'series' ? 'series' : 'film';
  final year = RegExp(
    r'^(?:18|19|20|21|22)\d{2}',
  ).firstMatch(title.year)?.group(0);
  final opening = [?year, if (genres.isNotEmpty) genres, kind].join(' ');
  final director = title.director.split(',').first.trim();
  final cast = title.actors
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .take(2)
      .join(' and ');
  final article = RegExp(r'^[aeiou]').hasMatch(opening) ? 'An' : 'A';
  final parts = <String>[
    director.isNotEmpty && director.length < 60
        ? '$article $opening directed by $director.'
        : '$article $opening.',
    if (cast.isNotEmpty && cast.length < 90) 'Featuring $cast.',
  ];
  return parts.join(' ');
}
