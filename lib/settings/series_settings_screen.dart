import 'package:flutter/material.dart';
import '../player/series_preferences.dart';

class SeriesSettingsScreen extends StatefulWidget {
  const SeriesSettingsScreen({super.key, this.preferences});
  final SeriesPreferences? preferences;
  @override
  State<SeriesSettingsScreen> createState() => _SeriesSettingsScreenState();
}

class _SeriesSettingsScreenState extends State<SeriesSettingsScreen> {
  late final prefs = widget.preferences ?? SeriesPreferences.shared;
  @override
  void initState() {
    super.initState();
    prefs.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Series & playback')),
    body: ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final v = prefs.value;
        final enabled = prefs.ready && !prefs.saving;
        final speeds = {
          5,
          10,
          25,
          50,
          100,
          250,
          500,
          1000,
          v.connectionMbps,
        }.toList()..sort();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!prefs.ready && prefs.error == null)
              const LinearProgressIndicator(),
            if (prefs.error != null) ...[
              Text(prefs.error!),
              if (!prefs.ready)
                TextButton(onPressed: prefs.load, child: const Text('Retry')),
            ],
            Text(
              'Episode playback',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Choose a suitable release automatically'),
              subtitle: const Text(
                'For episode Play and player Previous / Next. Uses exact episode matches, known size/runtime and a conservative connection budget. Otherwise shows releases for you to choose.',
              ),
              value: v.autoSelect,
              onChanged: enabled
                  ? (x) => prefs.save(v.copyWith(autoSelect: x))
                  : null,
            ),
            const Text('Usenet connection budget (Mbps)'),
            DropdownButton<int>(
              value: v.connectionMbps,
              isExpanded: true,
              items: [
                for (final speed in speeds)
                  DropdownMenuItem(value: speed, child: Text('$speed Mbps')),
              ],
              onChanged: enabled
                  ? (x) {
                      if (x != null) prefs.save(v.copyWith(connectionMbps: x));
                    }
                  : null,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Set the sustained speed available to this app, not your advertised broadband maximum. No background speed test is run. Estimates reserve 40% headroom; segment availability and codec playback are not guaranteed.',
              ),
            ),
            const Text('Maximum preferred resolution'),
            DropdownButton<int>(
              value: v.maxHeight,
              isExpanded: true,
              items: [
                for (final height in [480, 720, 1080, 2160])
                  DropdownMenuItem(value: height, child: Text('${height}p')),
              ],
              onChanged: enabled
                  ? (x) {
                      if (x != null) prefs.save(v.copyWith(maxHeight: x));
                    }
                  : null,
            ),
            const SizedBox(height: 28),
            Text(
              'Episode display & spoilers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show episode names'),
              subtitle: const Text(
                'Names are shown by default, independently of plot spoilers.',
              ),
              value: v.showTitles,
              onChanged: enabled
                  ? (x) => prefs.save(v.copyWith(showTitles: x))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show episode stills'),
              subtitle: const Text(
                'Stills may reveal a scene. Requires configured TMDB access and artwork enabled.',
              ),
              value: v.showStills,
              onChanged: enabled
                  ? (x) => prefs.save(v.copyWith(showStills: x))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show episode plot summaries'),
              subtitle: const Text(
                'May reveal story details. Hidden by default.',
              ),
              value: v.showSynopsis,
              onChanged: enabled
                  ? (x) => prefs.save(v.copyWith(showSynopsis: x))
                  : null,
            ),
            const Text(
              'These preferences apply to every series. Setup text currently uses English fallback.',
            ),
          ],
        );
      },
    ),
  );
}
