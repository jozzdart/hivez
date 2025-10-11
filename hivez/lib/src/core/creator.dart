part of 'core.dart';

abstract class NativeBoxCreator {
  /// Const constructor for subclasses.
  const NativeBoxCreator();

  /// Singleton instance of the default [BoxCreator] implementation.
  static final NativeBoxCreator _instance = const NativeBoxCreatorImpl();

  static NativeBox<K, T> newBox<K, T>(
    String name, {
    BoxType type = BoxType.regular,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) =>
      boxFromConfig(NativeBoxConfig(
        name,
        type: type,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
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
  static NativeBox<K, T> boxFromConfig<K, T>(
    NativeBoxConfig config,
  ) =>
      _instance._createBox(config);

  /// Internal method to create a [BoxInterface] from a [BoxConfig].
  ///
  /// Subclasses must implement this to provide the actual box creation logic.
  NativeBox<K, T> _createBox<K, T>(NativeBoxConfig config);
}

/// Concrete implementation of [BoxCreator] that instantiates the correct
/// [BoxInterface] subclass based on the [BoxConfig.type].
///
/// This class is not intended to be used directly; use [BoxCreator] static
/// methods instead.
class NativeBoxCreatorImpl implements NativeBoxCreator {
  const NativeBoxCreatorImpl();

  @override
  NativeBox<K, T> _createBox<K, T>(
    NativeBoxConfig config,
  ) {
    return switch (config.type) {
      BoxType.regular => NativeBoxImpl<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
        ),
      BoxType.lazy => NativeBoxLazyImpl<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
        ),
      BoxType.isolated => NativeBoxIsolatedImpl<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
        ),
      BoxType.isolatedLazy => NativeBoxIsolatedLazyImpl<K, T>(
          config.name,
          encryptionCipher: config.encryptionCipher,
          crashRecovery: config.crashRecovery,
          path: config.path,
          collection: config.collection,
        ),
    };
  }
}
