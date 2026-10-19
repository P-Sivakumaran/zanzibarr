import 'package:flutter/material.dart';
import '../player/track_language.dart';
import 'ui_preferences.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key, this.uiPreferences});
  final UiPreferencesController? uiPreferences;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Language & region')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (uiPreferences != null)
                ListenableBuilder(
                  listenable: uiPreferences!,
                  builder: (context, _) => DropdownButtonFormField<Locale>(
                    isExpanded: true,
                    initialValue: uiPreferences!.locale,
                    decoration: const InputDecoration(
                      labelText: 'App language',
                    ),
                    items: [
                      for (final (locale, name) in supportedAppLocales)
                        DropdownMenuItem(value: locale, child: Text(name)),
                    ],
                    onChanged: (locale) async {
                      if (locale == null) return;
                      try {
                        await uiPreferences!.setLocale(locale);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('App language could not be saved.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'New discovery and library text currently uses English fallback. OMDb supplies metadata in its source language; the app language does not translate it.',
              ),
              const SizedBox(height: 24),
              const MediaLanguageSettings(),
            ],
          ),
        ),
      ),
    ),
  );
}

class MediaLanguageSettings extends StatefulWidget {
  const MediaLanguageSettings({super.key, this.store});
  final TrackLanguageStore? store;
  @override
  State<MediaLanguageSettings> createState() => _MediaLanguageSettingsState();
}

class _MediaLanguageSettingsState extends State<MediaLanguageSettings> {
  late final _store = widget.store ?? TrackLanguageStore();
  TrackLanguagePreferences _value = const TrackLanguagePreferences();
  bool _loaded = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _store.load();
      if (mounted) {
        setState(() {
          _value = value;
          _loaded = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Language preferences could not be loaded.');
      }
    }
  }

  Future<void> _save(String value, bool audio) async {
    final next = TrackLanguagePreferences(
      audio: audio ? value : _value.audio,
      subtitle: audio ? _value.subtitle : value,
    );
    setState(() => _saving = true);
    try {
      await _store.save(next);
      if (mounted) {
        setState(() {
          _value = next;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Language preferences could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Media languages', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      for (final audio in [true, false])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            key: ValueKey(
              '${audio ? 'audio' : 'subtitle'}:${audio ? _value.audio : _value.subtitle}',
            ),
            isExpanded: true,
            initialValue: audio ? _value.audio : _value.subtitle,
            decoration: InputDecoration(
              labelText: audio ? 'Preferred audio' : 'Preferred subtitles',
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Keep player default'),
              ),
              if (!audio)
                const DropdownMenuItem(value: 'no', child: Text('Off')),
              for (final language in mediaLanguages.entries)
                DropdownMenuItem(
                  value: language.key,
                  child: Text('${language.value} (${language.key})'),
                ),
            ],
            onChanged: !_loaded || _saving
                ? null
                : (value) => _save(value!, audio),
          ),
        ),
      const Text(
        'Applies to detected tracks on the next playback. Missing languages keep the player default. Manual track choices take priority. Forced/SDH labels and external tracks remain available in the player; no country flag is guessed from a language.',
      ),
      if (_saving) const LinearProgressIndicator(),
      if (_error != null) ...[
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ],
  );
}
