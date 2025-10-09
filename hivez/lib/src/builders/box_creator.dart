part of 'builders.dart';

/// {@template box_creator}
/// Abstract factory for creating strongly-typed Hive boxes of various types.
///
/// This class provides static and instance methods to create [BoxInterface]s
/// (regular, lazy, isolated, or isolated lazy) using either direct parameters
/// or a [BoxConfig] object. It is the central entry point for all box creation
/// in the Hivez package.
///
/// Use [BoxCreator.newBox] for direct creation, or [BoxCreator.boxFromConfig]
/// for configuration-driven creation. The actual implementation is delegated
/// to a private singleton instance of [BoxCreatorImpl].
///
/// Example:
/// ```dart
/// // Create a regular box
/// final box = BoxCreator.newBox<int, User>('users');
///
/// // Create a lazy box with encryption
/// final box = BoxCreator.newBox<String, MyModel>(
///   'myBox',
///   type: BoxType.lazy,
///   encryptionCipher: myCipher,
/// );
///
/// // Create a box from a config
/// final config = BoxConfig.isolated('myBox', logger: myLogger);
/// final box = BoxCreator.boxFromConfig<String, MyModel>(config);
/// ```
/// {@endtemplate}
abstract class BoxCreator {
  /// Const constructor for subclasses.
  const BoxCreator();

  /// Singleton instance of the default [BoxCreator] implementation.
  static final BoxCreator _instance = const BoxCreatorImpl();

  /// Creates a new [BoxInterface] of the specified type and key/value types.
  ///
  /// This is the main entry point for creating a box with explicit parameters.
  ///
  /// - [name]: The unique name of the box.
  /// - [type]: The type of box to create (regular, lazy, isolated, isolatedLazy).
  /// - [encryptionCipher]: Optional cipher for transparent encryption/decryption.
  /// - [crashRecovery]: Enables crash recovery if true (default: true).
  /// - [path]: Optional custom file system path for box storage.
  /// - [collection]: Optional logical collection/grouping for the box.
  /// - [logger]: Optional logger for box events.
  ///
  /// Returns a [BoxInterface] of the appropriate type.
  static BoxInterface<K, T> newBox<K, T>(
    String name, {
    BoxType type = BoxType.regular,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      boxFromConfig(BoxConfig(
        name,
        type: type,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
      ));

  /// Creates a [BoxInterface] from a [BoxConfig] object.
  ///
  /// This method delegates to the internal singleton [BoxCreatorImpl].
  ///
  /// Example:
  /// ```dart
  /// final config = BoxConfig.lazy('myBox');
  /// final box = BoxCreator.boxFromConfig<String, MyModel>(config);
  /// ```
  static BoxInterface<K, T> boxFromConfig<K, T>(
    BoxConfig config,
  ) =>
      _instance._createBox(config);

  /// Internal method to create a [BoxInterface] from a [BoxConfig].
  ///
  /// Subclasses must implement this to provide the actual box creation logic.
  BoxInterface<K, T> _createBox<K, T>(BoxConfig config);
}

/// Concrete implementation of [BoxCreator] that instantiates the correct
/// [BoxInterface] subclass based on the [BoxConfig.type].
///
/// This class is not intended to be used directly; use [BoxCreator] static
/// methods instead.
class BoxCreatorImpl implements BoxCreator {
  const BoxCreatorImpl();

  @override
  BoxInterface<K, T> _createBox<K, T>(
    BoxConfig config,
  ) {
    return switch (config.type) {
      BoxType.regular => HivezBox<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
          logger: config.logger,
        ),
      BoxType.lazy => HivezBoxLazy<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
          logger: config.logger,
        ),
      BoxType.isolated => HivezBoxIsolated<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
          logger: config.logger,
        ),
      BoxType.isolatedLazy => HivezBoxIsolatedLazy<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
          logger: config.logger,
        ),
    };
  }
}
