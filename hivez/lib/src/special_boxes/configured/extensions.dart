part of 'configured_box.dart';

/// Extension on [BoxConfig] to easily create a [ConfiguredBox] instance.
///
/// This extension provides a convenient method to instantiate a [ConfiguredBox]
/// from a [BoxConfig] object, allowing you to specify the key and value types
/// for the box. This is especially useful for scenarios where you want to
/// programmatically create boxes with custom configurations.
///
/// Example:
/// ```dart
/// final config = BoxConfig('myBox', type: BoxType.lazy);
/// final box = config.createConfiguredBox<String, int>();
/// ```
extension CreateConfiguredBoxFromConfig on BoxConfig {
  /// Creates a [ConfiguredBox] of type [K], [T] using this [BoxConfig].
  ///
  /// Returns a new [ConfiguredBox] instance wrapping a box created from this config.
  ConfiguredBox<K, T> createConfiguredBox<K, T>() => ConfiguredBox(this);
}

/// Extension on [SharedLock] to create [LockedOperation] instances.
///
/// This extension provides a method to create a [LockedOperation] from a [SharedLock],
/// optionally specifying an operation name for debugging or logging purposes.
///
/// Example:
/// ```dart
/// final lock = SharedLock();
/// final op = lock.operation('writeUser');
/// await op.run(() async { /* critical section */ });
/// ```
extension CreateLockedOperationFromLock on SharedLock {
  /// Creates a [LockedOperation] using this [SharedLock].
  ///
  /// - [name]: Optional name for the operation, useful for diagnostics.
  ///
  /// Returns a [LockedOperation] that uses this lock for synchronization.
  LockedOperation operation(String? name) =>
      LockedOperation(lock: this, name: name);
}
