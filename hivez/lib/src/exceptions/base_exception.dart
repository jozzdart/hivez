part of 'exceptions.dart';

/// {@template hivez_exception}
/// The base class for all exceptions and errors thrown by the Hivez library.
///
/// All custom exceptions in Hivez should extend this class to provide a consistent
/// interface for error handling, logging, and debugging. This class encapsulates
/// a human-readable error message, an optional underlying cause, and an optional
/// stack trace for advanced diagnostics.
///
/// **Best Practices:**
/// - Always throw a more specific subclass of [HivezException] that describes the failure context.
/// - Avoid throwing raw [Exception] or [Error] types within Hivez internals.
/// - Use the [message] to provide actionable information for developers.
///
/// {@endtemplate}
abstract class HivezException implements Exception {
  /// A human-readable description of the failure.
  ///
  /// This message should clearly describe what went wrong and, if possible,
  /// suggest how to resolve the issue. It is intended for developers and may
  /// be surfaced in logs or error reports.
  final String message;

  /// The optional underlying cause of this exception.
  ///
  /// This can be another [Exception], [Error], or any object that provides
  /// additional context about the root cause of the failure (e.g., an I/O error,
  /// a HiveError, or a platform-specific exception). This is useful for
  /// exception chaining and advanced diagnostics.
  final Object? cause;

  /// The optional stack trace captured at the time this exception was created.
  ///
  /// This is typically provided when rethrowing or wrapping another exception,
  /// allowing for more precise debugging and error reporting.
  final StackTrace? stackTrace;

  /// Creates a new [HivezException].
  ///
  /// The [message] parameter must not be null and should describe the error.
  /// The [cause] and [stackTrace] parameters are optional and may be used to
  /// provide additional diagnostic information.
  const HivezException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  /// Returns the short class name of this exception for logging and debugging.
  ///
  /// This is typically the runtime type of the exception.
  String get name => runtimeType.toString();

  /// Returns a detailed string representation of this exception.
  ///
  /// The output includes the exception name, message, and, if present, the
  /// underlying cause and stack trace. This is useful for logging and debugging.
  @override
  String toString() {
    final buffer = StringBuffer('$name: $message');
    if (cause != null) buffer.write('\nCaused by: $cause');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}
