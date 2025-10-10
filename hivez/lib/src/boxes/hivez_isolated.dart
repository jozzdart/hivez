part of 'boxes.dart';

/// {@template hivez_box_isolated}
/// A strongly-typed, non-lazy Hive box implementation that operates in an isolated
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
/// Example usage:
/// ```dart
/// final box = HivezBoxIsolated<String, MyModel>('myBox');
/// await box.ensureInitialized();
/// await box.put('key', MyModel(...));
/// final value = await box.get('key');
/// ```
///
/// See also:
/// - [HivezBox] for the non-isolated version.
/// - [HivezBoxLazy] for the non-isolated lazy variant.
/// - [HivezBoxIsolatedLazy] for the lazy isolated variant.
/// {@endtemplate}
class HivezBoxIsolated<K, T>
    extends AbstractHivezIsolatedBox<K, T, IsolatedBox<T>> {
  @override
  bool get isLazy => false;

  /// Creates a new [HivezBoxIsolated] instance for strongly-typed, non-lazy Hive box access
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
  ///   not provided, Hive's default storage directory is used.
  /// - [collection]: An optional logical grouping for boxes, useful for organizing data
  ///   in larger applications or multi-tenant scenarios.
  /// - [logger]: An optional logger instance for capturing and reporting box events,
  ///   errors, or debugging information.
  ///
  /// Example:
  /// ```dart
  /// final box = HivezBoxIsolated<String, User>(
  ///   'users',
  ///   encryptionCipher: HiveAesCipher(myKey),
  ///   crashRecovery: true,
  ///   path: '/custom/hive/data',
  ///   collection: 'tenantA',
  ///   logger: myLogger,
  /// );
  /// await box.ensureInitialized();
  /// ```
  ///
  /// All configuration options are optional except [name]. The box will not be opened
  /// until [ensureInitialized] is called.
  HivezBoxIsolated(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  }) : super(
          nativeBox: NativeBoxCreator.newBox(
            name,
            type: BoxType.isolated,
            encryptionCipher: encryptionCipher,
            crashRecovery: crashRecovery,
            path: path,
            collection: collection,
          ),
        );

  @override
  BoxType get boxType => BoxType.isolated;

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _executeRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<List<T>> getMany(Iterable<K> keys) async {
    return _executeRead(() async {
      final values = <T>[];
      for (final key in keys) {
        final value = await box.get(key);
        if (value != null) values.add(value);
      }
      return values;
    });
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _executeRead(() => box.values);
  }

  @override
  Future<T?> valueAt(int index) async {
    return _executeRead(() => box.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _executeRead(() async {
      for (final key in (await box.keys)) {
        final value = await box.get(key);
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
  @override
  Future<Map<K, T>> toMap() async {
    return _executeRead(
        () async => Future.value((await box.toMap()).cast<K, T>()));
  }

  @override
  Future<IsolatedBox<T>> _openBox() => IsolatedHive.openBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );

  @override
  IsolatedBox<T> _getExistingBox() => IsolatedHive.box<T>(name);
}
