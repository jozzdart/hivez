part of 'boxes.dart';

/// {@template hivez_box_isolated_lazy}
/// A strongly-typed, lazy Hive box implementation that operates in an isolated
/// background process for improved performance and safety.
///
/// This class provides a high-level API for interacting with a Hive box in a Dart
/// isolate, enabling concurrent access and offloading heavy I/O operations from the
/// main thread. It is ideal for use cases where data integrity, responsiveness, and
/// crash resilience are critical.
///
/// Type Parameters:
///   - [K]: The type of keys used in the box.
///   - [T]: The type of values stored in the box.
///
/// See also:
/// - [HivezBox] for the non-isolated version.
/// - [HivezBoxLazy] for the non-isolated lazy variant.
/// - [HivezBoxIsolated] for the non-lazy isolated variant.
/// {@endtemplate}
class HivezBoxIsolatedLazy<K, T> extends BaseHivezBox<K, T> {
  /// Creates a new [HivezBoxIsolatedLazy] instance for strongly-typed, lazy Hive box access
  /// in a background isolate.
  ///
  /// This constructor initializes a Hive box that operates in a separate Dart isolate,
  /// providing improved performance and safety for concurrent and heavy I/O operations.
  /// It is suitable for scenarios where you want to offload database work from the main
  /// thread, such as in Flutter or server-side applications requiring high responsiveness
  /// and crash resilience.
  ///
  /// The [name] parameter specifies the unique name of the box. The optional parameters
  /// allow you to further configure the box:
  ///
  /// - [encryptionCipher]: An optional [HiveCipher] to transparently encrypt and decrypt
  ///   all data stored in the box. Use this for secure, at-rest encryption.
  /// - [crashRecovery]: If `true`, enables Hive's crash recovery mechanism to help prevent
  ///   data corruption in the event of unexpected shutdowns or crashes. Defaults to `false`.
  /// - [path]: An optional custom file system path where the box data will be stored. If
  ///   not specified, the default Hive storage directory is used.
  /// - [collection]: An optional collection name to namespace the box within a logical group.
  ///   This is useful for organizing related boxes or for multi-tenant applications.
  /// - [logger]: An optional logger for capturing diagnostic and error information. This can
  ///   be used to integrate with your application's logging infrastructure for better observability.
  ///
  /// Example usage:
  /// ```dart
  /// final box = HivezBoxIsolatedLazy<String, MyModel>('myLazyBox');
  /// await box.ensureInitialized();
  /// await box.put('key', MyModel(...));
  /// final value = await box.get('key');
  /// ```
  HivezBoxIsolatedLazy(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  }) : super(type: BoxType.isolatedLazy);
}
