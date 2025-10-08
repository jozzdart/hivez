part of 'builders.dart';

abstract class BoxCreator {
  const BoxCreator();

  static final BoxCreator _instance = const BoxCreatorImpl();

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

  static BoxInterface<K, T> boxFromConfig<K, T>(
    BoxConfig config,
  ) =>
      _instance._createBox(config);

  BoxInterface<K, T> _createBox<K, T>(BoxConfig config);
}

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
