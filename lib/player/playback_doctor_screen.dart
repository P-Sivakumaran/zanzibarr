import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'playback_diagnostics.dart';

String playbackStageLabel(PlaybackStage stage) => switch (stage) {
  PlaybackStage.preparing => 'Preparing playback',
  PlaybackStage.selectingMedia => 'Selecting media',
  PlaybackStage.connecting => 'Connecting and preparing the stream',
  PlaybackStage.openingDecoder => 'Opening video decoder',
  PlaybackStage.ready => 'Player ready',
  PlaybackStage.buffering => 'Waiting for more video data',
  PlaybackStage.paused => 'Playback paused',
  PlaybackStage.repairing => 'Repair in progress',
  PlaybackStage.failed => 'Playback needs attention',
  PlaybackStage.stopped => 'Playback stopped',
};

class PlaybackDoctorScreen extends StatelessWidget {
  const PlaybackDoctorScreen({super.key, required this.diagnostics});
  final PlaybackDiagnostics diagnostics;

  Future<void> _preview(BuildContext context) async {
    // Freeze the report: Copy exports exactly what the user previews.
    final report = diagnostics.report();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Preview diagnostic report'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: SelectableText(report)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy report'),
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: report));
                if (dialog.mounted) {
                  Navigator.pop(dialog);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostic report copied.'),
                      ),
                    );
                  }
                }
              } catch (_) {
                if (dialog.mounted) {
                  ScaffoldMessenger.of(dialog).showSnackBar(
                    const SnackBar(
                      content: Text('The report could not be copied.'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Playback Doctor')),
    body: ListenableBuilder(
      listenable: diagnostics,
      builder: (context, _) {
        final report = diagnostics.snapshot();
        final events = report['events'] as List;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    playbackStageLabel(diagnostics.stage),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Local player and engine observations. Error categories describe reported symptoms, not a confirmed root cause. Opening this page leaves playback running.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Chip(
                        label: Text(
                          'First frame: ${report['firstFrameMs'] ?? 'not observed'}${report['firstFrameMs'] == null ? '' : ' ms'}',
                        ),
                      ),
                      Chip(
                        label: Text('Rebuffering: ${report['rebufferMs']} ms'),
                      ),
                      Chip(
                        label: Text(
                          'Rebuffer episodes: ${report['rebufferCount']}',
                        ),
                      ),
                      if (diagnostics.failure != null)
                        Chip(
                          label: Text(
                            'Reported category: ${diagnostics.failure!.name}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'The report includes event names and relative timings only. It excludes titles, filenames, URLs, NZBs, credentials and media. Nothing is sent automatically. New diagnostic copy uses English.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      onPressed: () => _preview(context),
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Preview report'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final event in events.reversed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.circle_outlined, size: 16),
                      title: Text('${event['event']}'),
                      subtitle: Text(
                        'Attempt ${event['attempt']} / +${event['elapsedMs']} ms',
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Native engine events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if ((report['nativeEvents'] as List).isEmpty)
                    const Text(
                      'No native observations yet. Local-file playback does not use the Usenet engine.',
                    ),
                  for (final event in (report['nativeEvents'] as List).reversed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${event['event']}'),
                      subtitle: Text(
                        'Engine +${event['elapsedMs']} ms / event ${event['sequence']}',
                      ),
                    ),
                  if ((report['droppedEvents'] as int) > 0)
                    Text(
                      '${report['droppedEvents']} older events omitted from this bounded report.',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
