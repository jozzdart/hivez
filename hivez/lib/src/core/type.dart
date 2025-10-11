part of 'core.dart';

/// The type of Hive box to create or interact with.
///
/// - [regular]: A standard, non-lazy, non-isolated Hive box.
/// - [lazy]: A lazy box that loads values on demand, reducing memory usage.
/// - [isolated]: A non-lazy box that operates in a background isolate for concurrency and safety.
/// - [isolatedLazy]: A lazy box that also operates in a background isolate.
enum BoxType {
  /// Standard, non-lazy, non-isolated Hive box.
  regular,

  /// Lazy box that loads values on demand.
  lazy,

  /// Non-lazy box running in a background isolate.
  isolated,

  /// Lazy box running in a background isolate.
  isolatedLazy,
}
