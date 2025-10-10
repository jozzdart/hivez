part of 'indexed.dart';

/// Base exception for all errors related to [IndexedBox] operations.
///
/// This exception is thrown when an error occurs in the context of an
/// [IndexedBox], such as index corruption, rebuild failures, or other
/// index-related issues. It extends [HivezBoxException] to provide
/// additional context about the affected box.
///
/// All [IndexedBox] exceptions should extend this class.
class IndexedBoxException extends HivezBoxException {
  /// Creates a new [IndexedBoxException].
  ///
  /// - [boxName]: The name of the box where the error occurred.
  /// - [message]: A human-readable error message.
  /// - [cause]: The underlying exception that caused this error, if any.
  /// - [stackTrace]: The stack trace associated with the error, if available.
  IndexedBoxException({
    required super.boxName,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when an index rebuild operation fails in an [IndexedBox].
///
/// This exception indicates that the attempt to rebuild the full-text index
/// was unsuccessful, possibly due to data corruption, I/O errors, or other
/// unexpected failures. The box may be left in an inconsistent state and
/// may require manual intervention or a full reset.
class IndexRebuildFailed extends IndexedBoxException {
  /// Creates a new [IndexRebuildFailed] exception.
  ///
  /// - [boxName]: The name of the box whose index failed to rebuild.
  /// - [cause]: The underlying exception that caused the rebuild to fail, if any.
  /// - [stackTrace]: The stack trace associated with the error, if available.
  IndexRebuildFailed({
    required super.boxName,
    super.cause,
    super.stackTrace,
  }) : super(message: "Index rebuild failed");
}

/// Exception thrown when index corruption is detected in an [IndexedBox].
///
/// This exception indicates that the index data structure is corrupt and
/// cannot be used for search or update operations. The recommended action
/// is to trigger a full index rebuild to restore consistency.
///
/// This may be thrown during index validation, search, or update operations.
class IndexCorruptionDetected extends IndexedBoxException {
  /// Creates a new [IndexCorruptionDetected] exception.
  ///
  /// - [boxName]: The name of the box whose index is corrupt.
  /// - [cause]: The underlying exception that led to the corruption detection, if any.
  /// - [stackTrace]: The stack trace associated with the error, if available.
  IndexCorruptionDetected({
    required super.boxName,
    super.cause,
    super.stackTrace,
  }) : super(message: "Index is corrupt, requires rebuild.");
}
