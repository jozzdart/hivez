part of 'builders.dart';

class Box<K, T> extends BoxDecorator<K, T> {
  Box(
    String name, {
    BoxType type = BoxType.regular,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    void Function(String)? logger,
  }) : super(BoxConfig(
          name,
          type: type,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ).createBox<K, T>());

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

extension CreateBoxFromConfigExtensions on BoxConfig {
  Box<K, T> box<K, T>() => Box<K, T>.fromConfig(this);
}

extension CreateBoxFromTypeExtensions on BoxType {
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
