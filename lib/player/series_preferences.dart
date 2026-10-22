import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'media_preferences.dart';

class SeriesOptions {
  const SeriesOptions({
    this.autoSelect = false,
    this.connectionMbps = 25,
    this.maxHeight = 1080,
    this.showTitles = true,
    this.showStills = true,
    this.showSynopsis = false,
  });
  final bool autoSelect, showTitles, showStills, showSynopsis;
  final int connectionMbps, maxHeight;
  SeriesOptions copyWith({
    bool? autoSelect,
    int? connectionMbps,
    int? maxHeight,
    bool? showTitles,
    bool? showStills,
    bool? showSynopsis,
  }) => SeriesOptions(
    autoSelect: autoSelect ?? this.autoSelect,
    connectionMbps: connectionMbps ?? this.connectionMbps,
    maxHeight: maxHeight ?? this.maxHeight,
    showTitles: showTitles ?? this.showTitles,
    showStills: showStills ?? this.showStills,
    showSynopsis: showSynopsis ?? this.showSynopsis,
  );
  Map<String, Object> toJson() => {
    'autoSelect': autoSelect,
    'connectionMbps': connectionMbps,
    'maxHeight': maxHeight,
    'showTitles': showTitles,
    'showStills': showStills,
    'showSynopsis': showSynopsis,
  };
  static SeriesOptions parse(Map data) {
    for (final key in [
      'autoSelect',
      'showTitles',
      'showStills',
      'showSynopsis',
    ]) {
      if (data[key] != null && data[key] is! bool) {
        throw const FormatException();
      }
    }
    final speed = data['connectionMbps'] ?? 25,
        height = data['maxHeight'] ?? 1080;
    if (speed is! int ||
        speed < 1 ||
        speed > 1000 ||
        ![480, 720, 1080, 2160].contains(height)) {
      throw const FormatException();
    }
    return SeriesOptions(
      autoSelect: data['autoSelect'] ?? false,
      connectionMbps: speed,
      maxHeight: height,
      showTitles: data['showTitles'] ?? true,
      showStills: data['showStills'] ?? true,
      showSynopsis: data['showSynopsis'] ?? false,
    );
  }
}

class SeriesPreferences extends ChangeNotifier {
  SeriesPreferences({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  static final shared = SeriesPreferences();
  final PlayerPreferenceStorage _storage;
  SeriesOptions value = const SeriesOptions();
  bool ready = false, saving = false;
  String? error;
  Future<void>? _loading;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final raw = await _storage
          .read('player.series.v1')
          .timeout(const Duration(seconds: 3));
      if (raw != null) {
        if (raw.length > 2048) throw const FormatException();
        value = SeriesOptions.parse(jsonDecode(raw) as Map);
      }
      ready = true;
      error = null;
    } catch (_) {
      error =
          'Series preferences could not be loaded. Retry before changing them.';
      _loading = null;
    }
    notifyListeners();
  }

  Future<bool> save(SeriesOptions next) async {
    if (!ready || saving) return false;
    saving = true;
    notifyListeners();
    try {
      SeriesOptions.parse(next.toJson());
      await _storage.write('player.series.v1', jsonEncode(next.toJson()));
      value = next;
      error = null;
      return true;
    } catch (_) {
      error =
          'Could not save series preferences. Your previous settings are unchanged.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
