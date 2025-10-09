part of 'configured_box.dart';

/// {@template locked_operation}
/// A utility class for running asynchronous operations within a [SharedLock].
///
/// [LockedOperation] provides a way to execute
/// critical sections of code under a named lock, ensuring mutual exclusion
/// for concurrent asynchronous operations. This is especially useful for
/// protecting shared resources, such as boxes or caches, from race conditions
/// in multi-isolate or multi-threaded environments.
///
/// The [name] property is used for diagnostics, logging, and error reporting,
/// making it easier to trace and debug locked operations in production systems.
///
/// Example usage:
/// ```dart
/// final lock = SharedLock();
/// final op = LockedOperation(lock: lock, name: 'writeUser');
/// await op.run(() async {
///   // critical section
/// });
/// ```
/// {@endtemplate}
class LockedOperation {
  /// Optional name for the operation, used for diagnostics and error reporting.
  final String? name;

  /// The underlying [SharedLock] used to synchronize the operation.
  final SharedLock _lock;

  /// Creates a [LockedOperation] that will run operations under the given [lock].
  ///
  /// - [lock]: The [SharedLock] instance to use for synchronization.
  /// - [name]: Optional name for the operation, useful for debugging and logging.
  const LockedOperation({
    this.name,
    required SharedLock lock,
  }) : _lock = lock;

  /// Runs the given asynchronous [operation] within the lock.
  ///
  /// - [operation]: The critical section to execute under lock.
  ///
  /// Returns the result of [operation] after acquiring the lock.
  /// If an error occurs, it is propagated after invoking any error handlers
  /// registered on the [SharedLock].
  ///
  /// Example:
  /// ```dart
  /// await op.run(() async {
  ///   // perform thread-safe work here
  /// });
  /// ```
  Future<T> run<T>(Future<T> Function() operation) =>
      _lock.runOperation(operation, name: name);
}
