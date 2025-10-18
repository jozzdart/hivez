part of 'builders.dart';

/// {@template box}
///
/// The [Box] class provides a convenient, type-safe, and composable API for
/// working with Hive boxes in Dart and Flutter applications. It acts as a
/// decorator over the underlying [BoxInterface], allowing you to easily
/// configure, open, and interact with boxes of various types (regular, lazy,
/// isolated, isolated lazy) using a unified interface.
///
/// Type Parameters:
///   - [K]: The type of keys used in the box.
///   - [T]: The type of values stored in the box.
///
/// Example usage:
/// ```dart
/// // Create a regular box
/// final box = Box<String, MyModel>.regular('myBox');
/// await box.put('key', MyModel(...));
/// final value = await box.get('key');
///
/// // Create a lazy box
/// final lazyBox = Box<String, MyModel>.lazy('myLazyBox');
///
/// // Create from config
/// final config = BoxConfig('myBox', type: BoxType.isolated);
/// final boxFromConfig = Box<String, MyModel>.fromConfig(config);
/// ```
///
/// See also:
/// - [BoxType] for available box types.
/// - [BoxConfig] for advanced configuration.
/// {@endtemplate}
class Box<K, T> extends BoxDecorator<K, T> {
  /// Optional logger for capturing diagnostic and error information.
  final LogHandler? logger;

  /// Creates a new [Box] instance with the given configuration.
  ///
  /// [name] is the unique name of the box.
  /// [type] specifies the box type (regular, lazy, isolated, isolatedLazy).
  /// [encryptionCipher] enables transparent encryption/decryption of box data.
  /// [crashRecovery] enables Hive's crash recovery mechanism (default: true).
  /// [path] is an optional custom file system path for the box.
  /// [collection] is an optional logical grouping for the box.
  /// [logger] is an optional log handler for diagnostics.
  Box(
    String name, {
    BoxType type = BoxType.regular,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    this.logger,
  }) : super(BoxConfig(
          name,
          type: type,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ).createBox<K, T>());

  /// Creates a [Box] from a [BoxConfig] instance.
  ///
  /// This factory is useful for advanced scenarios where box configuration
  /// is constructed dynamically or loaded from external sources.
  ///
  /// Example:
  /// ```dart
  /// final config = BoxConfig('myBox', type: BoxType.lazy);
  /// final box = Box<String, MyModel>.fromConfig(config);
  /// ```
  factory Box.fromConfig(
    BoxConfig config,
  ) =>
      Box(
        config.name,
        type: config.type,
        encryptionCipher: config.encryptionCipher,
        crashRecovery: config.crashRecovery,
        path: config.path,
        collection: config.collection,
        logger: config.logger,
      );

  /// Creates a strongly-typed, non-lazy, non-isolated [Box].
  ///
  /// This is the default, high-performance box type for most use cases.
  ///
  /// Example:
  /// ```dart
  /// final box = Box<String, MyModel>.regular('myBox');
  /// ```
  factory Box.regular(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      Box<K, T>(
        name,
        type: BoxType.regular,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a strongly-typed, lazy [Box].
  ///
  /// Lazy boxes load values from disk only when accessed, reducing memory usage.
  ///
  /// Example:
  /// ```dart
  /// final lazyBox = Box<String, MyModel>.lazy('myLazyBox');
  /// ```
  factory Box.lazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      Box<K, T>(
        name,
        type: BoxType.lazy,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a strongly-typed, non-lazy, isolated [Box].
  ///
  /// Isolated boxes run in a separate Dart isolate for improved concurrency and
  /// crash resilience, at the cost of some performance overhead.
  ///
  /// Example:
  /// ```dart
  /// final isoBox = Box<String, MyModel>.isolated('myIsoBox');
  /// ```
  factory Box.isolated(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      Box<K, T>(
        name,
        type: BoxType.isolated,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a strongly-typed, lazy, isolated [Box].
  ///
  /// This combines the benefits of lazy loading and isolate-based concurrency.
  ///
  /// Example:
  /// ```dart
  /// final isoLazyBox = Box<String, MyModel>.isolatedLazy('myIsoLazyBox');
  /// ```
  factory Box.isolatedLazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      Box<K, T>(
        name,
        type: BoxType.isolatedLazy,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );
}

/// Extension on [BoxConfig] to create a [Box] instance directly.
///
/// Example:
/// ```dart
/// final config = BoxConfig('myBox', type: BoxType.lazy);
/// final box = config.box<String, MyModel>();
/// ```
extension CreateBoxFromConfigExtensions on BoxConfig {
  /// Creates a [Box] from this [BoxConfig].
  Box<K, T> box<K, T>() => Box<K, T>.fromConfig(this);
}

/// Extension on [BoxType] to create a [Box] with a fluent API.
///
/// Example:
/// ```dart
/// final box = BoxType.isolated.box<String, MyModel>('myBox');
/// ```
extension CreateBoxFromTypeExtensions on BoxType {
  /// Creates a [Box] of this [BoxType] with the given parameters.
  Box<K, T> box<K, T>(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      Box<K, T>(
        name,
        type: this,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );
}
