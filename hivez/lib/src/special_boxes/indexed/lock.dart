part of 'indexed.dart';

/// Provides a lock for synchronizing operations on an [IndexedBox].
///
/// This lock ensures that concurrent operations on the box are properly
/// synchronized, preventing race conditions and ensuring data consistency.
/// It also provides error handling hooks for logging unexpected errors
/// during locked operations.
class IndexedBoxLock extends SharedLock {
  /// The [IndexedBox] instance this lock is associated with.
  final IndexedBox indexedBox;

  /// Creates an [IndexedBoxLock] for the given [indexedBox].
  ///
  /// Optionally, an [overrideLock] can be provided to use a custom lock
  /// implementation (primarily for advanced scenarios or testing).
  IndexedBoxLock(this.indexedBox, {super.overrideLock});

  /// Error handler for lock operations.
  ///
  /// If an error occurs during a locked operation, this handler is invoked.
  /// It logs the error using the [IndexedBox]'s logger, if available.
  @override
  Future<void> Function(String opName, Object error, StackTrace stack)?
      get onError => _onError;

  /// Internal error handler that logs errors to the [IndexedBox]'s logger.
  Future<void> _onError(String opName, Object error, StackTrace stack) async =>
      indexedBox.logger?.call(_msg(opName, error, stack));

  /// Formats an error message for logging.
  String _msg(String opName, Object error, StackTrace stack) {
    return '[ERROR with Indexed Box: ${indexedBox.name}] [$opName] Unexpected error: $error\n$stack';
  }
}

/// A specialized lock for [IndexedBox] operations that require journaled writes.
///
/// This lock ensures that all write operations are performed within the context
/// of the [IndexJournal], providing crash safety and atomicity for index updates.
class IndexedBoxLockJournal extends IndexedBoxLock {
  /// Creates an [IndexedBoxLockJournal] for the given [indexedBox].
  ///
  /// Optionally, an [overrideLock] can be provided to use a custom lock.
  IndexedBoxLockJournal(super.indexedBox, {super.overrideLock});

  /// Runs the given [body] function within a journaled write operation.
  ///
  /// This ensures that the index journal is properly updated before and after
  /// the operation, providing durability and recovery guarantees.
  @override
  Future<R> runner<R>(Future<R> Function() body) async {
    return await indexedBox._journal.runWrite(body);
  }
}

/// Extension methods for [IndexedBoxLockJournal].
extension IndexedBoxLockExtension on IndexedBoxLockJournal {
  /// Returns a lock that bypasses the journal for internal or read-only operations.
  ///
  /// This is useful for scenarios where you need to perform operations
  /// without triggering journaled writes, such as internal maintenance or
  /// read-only access.
  IndexedBoxLock get bypassJournal =>
      IndexedBoxLock(indexedBox, overrideLock: internalLock);
}
