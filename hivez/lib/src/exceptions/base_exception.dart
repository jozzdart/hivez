/// Base class for all Hivez-related errors.
///
/// Always prefer throwing subclasses that describe the failure context.
/// Avoid throwing raw [Exception] or [Error] types inside the Hivez internals.
abstract class HivezException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// Optional underlying cause (e.g. HiveError, IO error, etc.)
  final Object? cause;

  /// Optional stack trace captured at creation.
  final StackTrace? stackTrace;

  const HivezException(this.message, {this.cause, this.stackTrace});

  /// Short class name (for logs/debug)
  String get name => runtimeType.toString();

  @override
  String toString() {
    final buffer = StringBuffer('$name: $message');
    if (cause != null) buffer.write('\nCaused by: $cause');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}
