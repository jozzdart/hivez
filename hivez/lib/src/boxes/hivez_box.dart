part of 'boxes.dart';

/// {@template hivez_box}
/// A strongly-typed, non-lazy, non-isolated Hive box implementation.
///
/// This class provides a high-level API for interacting with a Hive box on the Dart
/// main thread. It is ideal for use cases where data integrity, responsiveness, and
/// crash resilience are critical.
///
/// Type Parameters:
///   - [K]: The type of keys used in the box.
///   - [T]: The type of values stored in the box.
///
/// Example usage:
/// ```dart
/// final box = HivezBox<String, MyModel>('myBox');
/// await box.ensureInitialized();
/// await box.put('key', MyModel(...));
/// final value = await box.get('key');
/// ```
///
/// See also:
/// - [HivezBoxLazy] for the lazy variant.
/// - [HivezBoxIsolated] for the isolated version.
/// - [HivezBoxIsolatedLazy] for the lazy isolated variant.
/// {@endtemplate}
class HivezBox<K, T> extends AbstractHivezBox<K, T, Box<T>> {
  @override
  bool get isLazy => false;

  /// Creates a new [HivezBox] instance for strongly-typed, non-lazy, non-isolated Hive box access.
  ///
  /// This constructor initializes a Hive box that operates on the main Dart thread,
  /// providing fast, synchronous access to the underlying data store. It is suitable
  /// for scenarios where you want direct, high-performance access to your data without
  /// the overhead of isolates or lazy loading.
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
  /// Example:
  /// ```dart
  /// final box = HivezBox<String, MyModel>(
  ///   'myBox',
  ///   encryptionCipher: MyCipher(),
  ///   crashRecovery: true,
  ///   path: '/custom/path',
  ///   collection: 'user_data',
  ///   logger: myLogger,
  /// );
  /// await box.ensureInitialized();
  /// ```
  HivezBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _executeRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _executeRead(() => Future.value(box.values));
  }

  @override
  Future<T?> valueAt(int index) async {
    return _executeRead(() => Future.value(box.getAt(index)));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _executeRead(() async {
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  /// Returns a map containing all key-value pairs in the box.
  ///
  /// This method retrieves the entire contents of the box as a strongly-typed
  /// `Map<K, T>`, where each key is associated with its corresponding value.
  ///
  /// Example:
  /// ```dart
  /// final map = await myBox.toMap();
  /// print(map); // {key1: value1, key2: value2, ...}
  /// ```
  Future<Map<K, T>> toMap() async {
    return _executeRead(() => Future.value(box.toMap().cast<K, T>()));
  }

  @override
  Future<Box<T>> _openBox() {
    return Hive.openBox<T>(
      name,
      encryptionCipher: _encryptionCipher,
      crashRecovery: _crashRecovery,
      path: _path,
      collection: _collection,
    );
  }

  @override
  Box<T> _getExistingBox() => Hive.box<T>(name);
}
