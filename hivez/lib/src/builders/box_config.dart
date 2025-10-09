part of 'builders.dart';

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

/// Extension to determine the [BoxType] of a [BoxInterface] at runtime.
///
/// This is useful for introspection and for generic code that needs to branch
/// based on the type of box (e.g., for optimizations or diagnostics).
extension GetTypeOfBoxInterfaceExtension<K, T> on BoxInterface<K, T> {
  /// Returns the [BoxType] of this box instance.
  ///
  /// - Returns [BoxType.isolatedLazy] if both [isIsolated] and [isLazy] are true.
  /// - Returns [BoxType.isolated] if [isIsolated] is true and [isLazy] is false.
  /// - Returns [BoxType.lazy] if [isLazy] is true and [isIsolated] is false.
  /// - Returns [BoxType.regular] otherwise.
  BoxType get type {
    if (isIsolated) return isLazy ? BoxType.isolatedLazy : BoxType.isolated;
    if (isLazy) return BoxType.lazy;
    return BoxType.regular;
  }
}

/// Immutable configuration for creating or opening a Hive box.
///
/// This class encapsulates all options required to configure a box, including
/// its name, type, encryption, crash recovery, storage path, collection, and logging.
///
/// Use the provided named constructors for convenience, or use [copyWith] to
/// create modified copies of an existing config.
///
/// Example:
/// ```dart
/// final config = BoxConfig.lazy(
///   'myBox',
///   encryptionCipher: myCipher,
///   crashRecovery: true,
///   path: '/custom/path',
///   collection: 'users',
///   logger: myLogger,
/// );
/// ```
class BoxConfig {
  /// The unique name of the box.
  final String name;

  /// The type of box to create (regular, lazy, isolated, isolatedLazy).
  final BoxType type;

  /// Optional cipher for transparent encryption/decryption.
  final HiveCipher? encryptionCipher;

  /// Whether crash recovery is enabled for this box.
  final bool crashRecovery;

  /// Optional custom file system path for box storage.
  final String? path;

  /// Optional logical collection name for namespacing.
  final String? collection;

  /// Optional logger for diagnostics and error reporting.
  final LogHandler? logger;

  /// Creates a new [BoxConfig] with the given parameters.
  ///
  /// [name] is required. All other parameters are optional and have sensible defaults.
  const BoxConfig(
    this.name, {
    this.type = BoxType.regular,
    this.encryptionCipher,
    this.crashRecovery = true,
    this.path,
    this.collection,
    this.logger,
  });

  /// Creates a [BoxConfig] for a regular (non-lazy, non-isolated) box.
  factory BoxConfig.regular(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(
        name,
        type: BoxType.regular,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a [BoxConfig] for a lazy box.
  factory BoxConfig.lazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(
        name,
        type: BoxType.lazy,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a [BoxConfig] for an isolated (background isolate) box.
  factory BoxConfig.isolated(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(
        name,
        type: BoxType.isolated,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a [BoxConfig] for an isolated lazy box.
  factory BoxConfig.isolatedLazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(
        name,
        type: BoxType.isolatedLazy,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Returns a copy of this config with the given fields replaced.
  ///
  /// This is useful for creating modified variants of an existing config.
  BoxConfig copyWith({
    String? name,
    BoxType? type,
    HiveCipher? encryptionCipher,
    bool? crashRecovery,
    String? path,
    String? collection,
    LogHandler? logger,
  }) {
    return BoxConfig(
      name ?? this.name,
      type: type ?? this.type,
      encryptionCipher: encryptionCipher ?? this.encryptionCipher,
      crashRecovery: crashRecovery ?? this.crashRecovery,
      path: path ?? this.path,
      collection: collection ?? this.collection,
      logger: logger ?? this.logger,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BoxConfig &&
        other.name == name &&
        other.type == type &&
        other.encryptionCipher == encryptionCipher &&
        other.crashRecovery == crashRecovery &&
        other.path == path &&
        other.collection == collection &&
        other.logger == logger;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      type.hashCode ^
      encryptionCipher.hashCode ^
      crashRecovery.hashCode ^
      path.hashCode ^
      collection.hashCode ^
      logger.hashCode;

  @override
  String toString() =>
      'BoxConfig($name, $type, cRec: $crashRecovery, pth: $path, col: $collection, log: $logger)';
}

/// Extension to create a [BoxInterface] from a [BoxConfig].
///
/// This provides a convenient way to instantiate a box using its configuration,
/// delegating to [BoxCreator.boxFromConfig].
extension CreateHivezBoxFromConfig on BoxConfig {
  /// Creates a [BoxInterface] of the appropriate type for the given key/value types.
  ///
  /// Example:
  /// ```dart
  /// final config = BoxConfig.lazy('myBox');
  /// final box = config.createBox<String, MyModel>();
  /// ```
  BoxInterface<K, T> createBox<K, T>() => BoxCreator.boxFromConfig(this);
}

/// Extension methods for [BoxType] to facilitate box creation and configuration.
///s
/// This allows you to easily create a [BoxConfig] or a [BoxInterface] directly
/// from a [BoxType] value.
extension CreationExtensionsBoxType on BoxType {
  /// Creates a [BoxConfig] for this [BoxType] with the given parameters.
  ///
  /// Example:
  /// ```dart
  /// final config = BoxType.lazy.boxConfig('myBox', encryptionCipher: cipher);
  /// ```
  BoxConfig boxConfig(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(
        name,
        type: this,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      );

  /// Creates a [BoxInterface] for this [BoxType] and the given key/value types.
  ///
  /// Example:
  /// ```dart
  /// final box = BoxType.isolated.createBox<String, MyModel>('myBox');
  /// ```
  BoxInterface<K, T> createBox<K, T>(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxCreator.boxFromConfig<K, T>(
        boxConfig(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
      );
}
