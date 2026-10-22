import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'film_research.dart';
import 'research_suggestions.dart';

class ResearchPanel extends StatefulWidget {
  const ResearchPanel({
    super.key,
    required this.research,
    required this.child,
    this.onUnavailable,
  });
  final Widget child;
  final VoidCallback? onUnavailable;
  final FilmResearch research;
  @override
  State<ResearchPanel> createState() => _ResearchPanelState();
}

class _ResearchPanelState extends State<ResearchPanel> {
  bool _unavailable = false;
  bool _ready = false;
  String? _error;
  @override
  void didUpdateWidget(covariant ResearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.research, widget.research)) {
      _unavailable = false;
      _ready = false;
      _error = null;
    }
  }

  Future<void> _open(ResearchSource source) async {
    try {
      if (ResearchSource.publicUri(source.uri.toString()) == null ||
          !await launchUrl(source.uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the source in your browser.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final research = widget.research;
    if (!research.hasSources) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No web sources were returned. Current catalogue, dates and availability remain unverified.',
            ),
          ),
          widget.child,
        ],
      );
    }
    final ready = research.googleSuggestions == null || _ready;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${research.provider} research',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Checked ${research.checkedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}. Sources may be incomplete or change.',
                ),
                const SizedBox(height: 8),
                if (research.googleSuggestions != null && !_unavailable)
                  ResearchSuggestions(
                    key: ObjectKey(research),
                    html: research.googleSuggestions!,
                    onReady: () {
                      if (mounted && !_ready) setState(() => _ready = true);
                    },
                    onUnavailable: () {
                      if (mounted && !_unavailable) {
                        setState(() => _unavailable = true);
                        widget.onUnavailable?.call();
                      }
                    },
                  ),
                if (_unavailable)
                  const Text(
                    'Search suggestions could not be displayed. This researched reply is hidden. Retry research or use Claude.',
                  )
                else if (ready) ...[
                  if (research.googleSuggestions != null)
                    SelectableText(research.text)
                  else
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Research notes'),
                      children: [SelectableText(research.text)],
                    ),
                  for (var i = 0; i < research.sources.length; i++)
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      onPressed: () => _open(research.sources[i]),
                      child: Text(
                        '[${i + 1}] ${research.sources[i].title} (${research.sources[i].uri.host})',
                      ),
                    ),
                ],
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
        if (ready && !_unavailable) widget.child,
      ],
    );
  }
}
