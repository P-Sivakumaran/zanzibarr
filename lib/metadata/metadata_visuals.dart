import 'package:flutter/material.dart';
import 'metadata_service.dart';

/// Source scales remain explicit. Motion explains magnitude, never availability
/// or confidence; reduced-motion users get the final value immediately.
class RatingMeters extends StatelessWidget {
  const RatingMeters({super.key, required this.media});
  final MediaTitle media;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 12,
    children: [
      for (final rating in media.ratings.entries)
        SizedBox(
          width: 220,
          child: Builder(
            builder: (context) {
              final fraction = _fraction(rating.key, rating.value);
              final count = media.ratingCounts[rating.key];
              final unit = rating.key == 'IMDb'
                  ? (count == 1 ? 'vote' : 'votes')
                  : (count == 1 ? 'critic review' : 'critic reviews');
              final formatted = count?.toString().replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},',
              );
              final label = fraction == null
                  ? 'unavailable'
                  : rating.key == 'Rotten Tomatoes'
                  ? '${_number(fraction * 100)}% positive'
                  : rating.key == 'IMDb'
                  ? '${_number(fraction * 10)}/10'
                  : '${_number(fraction * 100)}/100';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${rating.key}: $label'),
                  const SizedBox(height: 6),
                  if (fraction != null)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 450),
                      builder: (context, value, _) => ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    count == null
                        ? (rating.key == 'IMDb'
                              ? 'Vote count unavailable'
                              : 'Review count unavailable')
                        : 'Based on $formatted $unit',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Tooltip(
                    message: rating.key == 'Rotten Tomatoes'
                        ? 'Percentage of positive critic reviews'
                        : rating.key == 'IMDb'
                        ? 'Weighted user rating'
                        : 'Weighted critic score (Metascore)',
                    child: Text(
                      'via ${media.ratingProviders[rating.key] ?? media.provider}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    ],
  );
  String _number(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  double? _fraction(String source, String value) {
    final pattern = source == 'IMDb'
        ? r'^(\d+(?:\.\d+)?)(?:\s*/\s*10)?$'
        : source == 'Rotten Tomatoes'
        ? r'^(\d+(?:\.\d+)?)(?:\s*%|\s*/\s*100)$'
        : source == 'Metacritic'
        ? r'^(\d+(?:\.\d+)?)(?:\s*/\s*100)?$'
        : null;
    if (pattern == null) return null;
    final match = RegExp(pattern).firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match[1]!);
    final divisor = source == 'IMDb' ? 10 : 100;
    return number != null && number.isFinite && number >= 0 && number <= divisor
        ? number / divisor
        : null;
  }
}

class CollectionComposition extends StatelessWidget {
  const CollectionComposition({
    super.key,
    required this.films,
    required this.shows,
  });
  final int films, shows;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$films films, $shows TV shows',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$films ${films == 1 ? 'film' : 'films'} / $shows ${shows == 1 ? 'TV show' : 'TV shows'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 240,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: films + shows == 0 ? 0 : films / (films + shows),
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 350),
            builder: (context, value, _) => ExcludeSemantics(
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
