import 'dart:convert';
import 'package:media_kit/media_kit.dart';
import 'media_preferences.dart';
import '../settings/ui_preferences.dart';

final mediaLanguages = <String, String>{
  for (final (locale, name) in supportedAppLocales) locale.languageCode: name,
  'nl': 'Nederlands',
  'sv': 'Svenska',
};
String normalizeTrackLanguage(String? raw) {
  final parts = (raw ?? '')
      .trim()
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-');
  final code =
      const {
        'eng': 'en',
        'tur': 'tr',
        'spa': 'es',
        'ger': 'de',
        'deu': 'de',
        'fre': 'fr',
        'fra': 'fr',
        'por': 'pt',
        'ita': 'it',
        'rus': 'ru',
        'chi': 'zh',
        'zho': 'zh',
        'jpn': 'ja',
        'kor': 'ko',
        'hin': 'hi',
        'ara': 'ar',
        'per': 'fa',
        'fas': 'fa',
        'dut': 'nl',
        'nld': 'nl',
        'swe': 'sv',
      }[parts.first] ??
      parts.first;
  return [code, ...parts.skip(1)].join('-');
}

String trackLanguageLabel(String? raw) {
  final tag = normalizeTrackLanguage(raw);
  if (tag.isEmpty || tag == 'und') return 'Unknown language';
  final parts = tag.split('-');
  final name = mediaLanguages[parts.first];
  return name == null
      ? tag
      : '$name${parts.length > 1 ? ' (${parts.skip(1).join('-').toUpperCase()})' : ''}';
}

class TrackLanguagePreferences {
  const TrackLanguagePreferences({this.audio = '', this.subtitle = ''});
  final String audio; // empty: preserve player default
  final String subtitle; // empty: preserve default; no: explicitly off
}

class TrackLanguageStore {
  TrackLanguageStore({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  final PlayerPreferenceStorage _storage;
  Future<TrackLanguagePreferences> load() async {
    final raw = await _storage.read('media.languages.v1');
    if (raw == null) return const TrackLanguagePreferences();
    final data = jsonDecode(raw);
    String value(String key) =>
        data is Map &&
            data[key] is String &&
            (data[key] == '' ||
                mediaLanguages.containsKey(data[key]) ||
                (key == 'subtitle' && data[key] == 'no'))
        ? data[key] as String
        : '';
    return TrackLanguagePreferences(
      audio: value('audio'),
      subtitle: value('subtitle'),
    );
  }

  Future<void> save(TrackLanguagePreferences value) => _storage.write(
    'media.languages.v1',
    jsonEncode({'audio': value.audio, 'subtitle': value.subtitle}),
  );
}

AudioTrack? preferredAudio(List<AudioTrack> tracks, String preferred) {
  if (preferred.isEmpty) return null;
  final matches = tracks
      .where(
        (t) =>
            t.id != 'auto' &&
            t.id != 'no' &&
            !t.uri &&
            normalizeTrackLanguage(t.language).split('-').first == preferred,
      )
      .toList();
  return matches.where((t) => t.isDefault == true).firstOrNull ??
      matches.firstOrNull;
}

SubtitleTrack? preferredSubtitle(List<SubtitleTrack> tracks, String preferred) {
  if (preferred == 'no') return SubtitleTrack.no();
  if (preferred.isEmpty) return null;
  // Do not infer forced/SDH from a codec or rewrite track titles. When several
  // tracks match, retain the provider's default rather than guessing accessibility.
  final matches = tracks
      .where(
        (t) =>
            t.id != 'auto' &&
            t.id != 'no' &&
            !t.uri &&
            !t.data &&
            normalizeTrackLanguage(t.language).split('-').first == preferred,
      )
      .toList();
  return matches.where((t) => t.isDefault == true).firstOrNull ??
      matches.firstOrNull;
}
