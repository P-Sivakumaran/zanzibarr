import 'edition_config.dart';
import 'package:flutter/material.dart';
import 'edition.dart';

/// A deliberately closed composition. No Legacy routes, arbitrary metadata,
/// AI, provider webviews, history or native media entrypoints are imported.
/// A production catalogue cannot be populated by guessing rating jurisdictions.
class CleanApp extends StatelessWidget {
  const CleanApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: const ValueKey(builtArtifactMarker),
    title: Edition.displayName,
    theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
    home: Scaffold(
      appBar: AppBar(title: const Text('Zanzibarr Clean')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, size: 48),
                SizedBox(height: 24),
                Text('Approved library', style: TextStyle(fontSize: 28)),
                SizedBox(height: 16),
                Text('No verified catalogue is connected yet.'),
                SizedBox(height: 16),
                Text(
                  'Clean withholds titles without trusted, region-specific '
                  'classification evidence. A title rating also cannot verify '
                  'the contents of an arbitrary video file or Usenet release. '
                  'Playback, imports and unverified recommendations remain '
                  'unavailable until those checks can be completed.',
                ),
                SizedBox(height: 16),
                Text('Your existing Zanzibarr library is kept separate.'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
