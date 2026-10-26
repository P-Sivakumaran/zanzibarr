import 'edition_config.dart';

enum AppEdition { legacy, clean, restricted }

abstract final class Edition {
  static final current = AppEdition.values.singleWhere(
    (value) => value.name == builtEdition,
    orElse: () => throw StateError('Unknown application edition'),
  );

  static String get displayName => switch (current) {
    AppEdition.legacy => 'Zanzibarr',
    AppEdition.clean => 'Zanzibarr Clean',
    AppEdition.restricted => 'Zanzibarr Restricted',
  };

  static String storageKey(String key, {AppEdition? edition}) {
    final scope = edition ?? current;
    return scope == AppEdition.legacy ? key : 'zanzibarr.${scope.name}.v1.$key';
  }

  static void verifyNative(String info) {
    if (!info.endsWith(';edition=${current.name};policy=$builtPolicy')) {
      throw StateError('Application and native edition do not match');
    }
  }

  // Legacy updates cannot establish either new edition's publisher/channel.
  // Keep new editions off /releases/latest until signed channels are deployed.
  static bool get legacyUpdatesAllowed => current == AppEdition.legacy;
}
