part of 'boxes.dart';

/// {@template hivez_box_lazy}
/// A strongly-typed, lazy Hive box implementation.
///
/// This class provides a high-level API for interacting with a Hive box on the Dart
/// main thread, utilizing Hive's lazy loading mechanism for efficient memory usage.
/// It is ideal for use cases where data integrity, responsiveness, and crash resilience
/// are critical, and where loading all data into memory at once is not desirable.
///
/// Type Parameters:
///   - [K]: The type of keys used in the box.
///   - [T]: The type of values stored in the box.
///
/// See also:
/// - [HivezBox] for the non-isolated version.
/// - [HivezBoxIsolated] for the isolated version.
/// - [HivezBoxIsolatedLazy] for the lazy isolated variant.
/// {@endtemplate}
class HivezBoxLazy<K, T> extends AbstractHivezBox<K, T, LazyBox<T>> {
  @override
  bool get isLazy => true;

  /// Creates a new [HivezBoxLazy] instance for strongly-typed, lazy Hive box access.
  ///
  /// This constructor initializes a Hive box that leverages Hive's lazy loading
  /// capabilities, meaning values are loaded from disk only when accessed, rather
  /// than being fully loaded into memory. This is particularly beneficial for
  /// applications dealing with large datasets or running on resource-constrained
  /// devices, such as mobile or embedded systems.
  ///
  /// The [name] parameter specifies the unique name of the box. The optional parameters
  /// allow you to further configure the box:
  ///
  /// - [encryptionCipher]: An optional [HiveCipher] to transparently encrypt and decrypt
  ///   all data stored in the box. Use this for secure, at-rest encryption of sensitive data.
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
  /// final box = HivezBoxLazy<String, MyModel>('myLazyBox');
  /// await box.ensureInitialized();
  /// await box.put('key', MyModel(...));
  /// final value = await box.get('key');
  /// ```
  ///
  /// {@macro hivez_box_lazy}
  HivezBoxLazy(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<LazyBox<T>> _openBox() => Hive.openLazyBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );

  @override
  LazyBox<T> _getExistingBox() => Hive.lazyBox<T>(name);

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _executeRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _executeRead(() async {
      final keys = box.keys.cast<K>();
      final List<T> values = [];
      for (final key in keys) {
        final value = await box.get(key);
        if (value != null) values.add(value);
      }
      return values;
    });
  }

  @override
  Future<T?> valueAt(int index) async {
    return _executeRead(() => box.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _executeRead(() async {
      for (final key in box.keys) {
        final value = await box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }
}
