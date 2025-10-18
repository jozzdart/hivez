part of 'configured_box.dart';

/// A shareable lock for synchronizing asynchronous operations.
///
/// [SharedLock] wraps a [Lock] from the `synchronized` package, providing
/// a reusable locking mechanism for critical sections across multiple operations,
/// such as read/write access to a shared resource or box.
///
/// It supports error handling via the [onError] callback, allowing you to
/// intercept and log or process errors that occur within locked operations.
///
/// Example usage:
/// ```dart
/// final lock = SharedLock();
/// await lock.runOperation(() async {
///   // critical section
/// });
/// ```
class SharedLock {
  /// The underlying [Lock] instance used for synchronization.
  final Lock _lock;

  /// Optional callback invoked when an error occurs during a locked operation.
  ///
  /// - [opName]: The name of the operation (if provided).
  /// - [error]: The error thrown.
  /// - [stack]: The stack trace associated with the error.
  ///
  /// If set, this callback is awaited before the error is rethrown.
  Future<void> Function(String opName, Object error, StackTrace stack)? onError;

  /// Creates a [SharedLock].
  ///
  /// - [overrideLock]: Optionally provide a custom [Lock] implementation.
  ///   If not provided, a new [Lock] is created.
  SharedLock({
    Lock? overrideLock,
  }) : _lock = overrideLock ?? Lock();

  /// Runs the given [body] function within a synchronized critical section.
  ///
  /// - [body]: The asynchronous function to execute under lock.
  /// - [name]: Optional name for the operation, used for diagnostics and error reporting.
  ///
  /// If an error occurs, the [onError] callback (if set) is invoked with the
  /// operation name, error, and stack trace before the error is rethrown.
  ///
  /// Returns the result of [body].
  Future<R> runOperation<R>(Future<R> Function() body, {String? name}) async {
    try {
      return await _runWrite(body);
    } catch (e, st) {
      if (onError != null) {
        await onError!(name ?? 'Unknown', e, st);
      }
      rethrow;
    }
  }

  /// Internal runner for executing the [body] function.
  ///
  /// This method can be overridden for testing or instrumentation.
  @internal
  Future<R> runner<R>(Future<R> Function() body) => body();

  /// Internal helper to run [body] within the [_lock] using [runner].
  ///
  /// Ensures that all operations use the same locking discipline.
  Future<R> _runWrite<R>(Future<R> Function() body) =>
      _lock.synchronized(() => runner(body));
}

/// Extension providing access to the internal [Lock] of a [SharedLock].
@internal
extension SharedLockExtension on SharedLock {
  /// Returns the underlying [Lock] instance used by this [SharedLock].
  Lock get internalLock => _lock;
}
