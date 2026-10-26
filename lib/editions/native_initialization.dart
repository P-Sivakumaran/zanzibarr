/// A process-wide native bridge is initialized once, even when an authenticated
/// application subtree is destroyed and recreated. Failed attempts may retry.
class NativeInitialization {
  Future<void>? _pending;
  Future<void> ensure(Future<void> Function() initialize) =>
      _pending ??= Future<void>.sync(initialize).catchError((
        Object error,
        StackTrace stack,
      ) {
        _pending = null;
        Error.throwWithStackTrace(error, stack);
      });
}
