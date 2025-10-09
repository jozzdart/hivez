import 'package:hivez/src/exceptions/exceptions.dart';

/// {@template hivez_box_exception}
/// Exception thrown for general box-level failures in the Hivez storage system.
///
/// This exception is used to indicate problems that occur at the box level, such as:
/// - I/O errors (e.g., file system failures, permission issues)
/// - Locking or concurrency violations
/// - Data corruption or integrity problems
/// - Unexpected internal errors specific to a particular box
///
/// The [boxName] parameter identifies the box where the error occurred, and the
/// [message] should provide a clear, actionable description of the failure context.
///
/// Example usage:
/// ```dart
/// try {
///   await box.write('key', value);
/// } on HivezBoxException catch (e) {
///   print('Box error: ${e.message}');
/// }
/// ```
///
/// {@endtemplate}
class HivezBoxException extends HivezException {
  /// Creates a new [HivezBoxException] for the specified [boxName] and [message].
  ///
  /// The [boxName] must not be null and should uniquely identify the box involved.
  /// The [message] should describe the error in a way that helps developers
  /// understand and resolve the issue.
  ///
  /// Optionally, a [cause] and [stackTrace] can be provided for advanced diagnostics.
  const HivezBoxException({
    required String boxName,
    required String message,
    super.cause,
    super.stackTrace,
  }) : super('[BOX: $boxName] $message');
}
