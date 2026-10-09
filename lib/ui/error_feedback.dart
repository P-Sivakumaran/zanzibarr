import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../player/playback_startup_guard.dart' show sanitizeErrorDetails;

/// Classify errors without displaying raw provider/indexer responses or URLs.
/// Exceptions can contain credentials, so the original text stays private.
String friendlyError(
  BuildContext context,
  Object error, {
  required String fallback,
}) {
  final l10n = AppLocalizations.of(context);
  final text = error.toString().toLowerCase();
  if (text.contains('nzb') &&
      (text.contains('parse') ||
          text.contains('corrupt') ||
          text.contains('read'))) {
    return l10n.errNzbUnreadable;
  }
  return fallback;
}

String safeErrorDetails(Object error, {Iterable<String> secrets = const []}) {
  var text = error.toString();
  for (final secret in secrets) {
    if (secret.isNotEmpty) text = text.replaceAll(secret, '***');
  }
  final sanitized = sanitizeErrorDetails(text);
  return sanitized.length > 1000
      ? '${sanitized.substring(0, 1000)}…'
      : sanitized;
}
