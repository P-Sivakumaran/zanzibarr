import 'package:flutter/foundation.dart';

/// The app has one active player. Lock dispatch is synchronous so stopping
/// media is issued before navigator disposal or preference-storage draining.
abstract final class EditionPlaybackLock {
  static VoidCallback? stop;
  static void revoke() => stop?.call();
}
