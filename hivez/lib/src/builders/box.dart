part of 'builders.dart';

class Box<K, T> extends BoxDecorator<K, T> {
  Box(BoxConfig config) : super(config.createBox<K, T>());

  factory Box.create(
    String name, {
    BoxType type = BoxType.regular,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      Box<K, T>(
        BoxConfig(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
          type: type,
        ),
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
        BoxConfig.regular(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
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
        BoxConfig.lazy(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
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
        BoxConfig.isolated(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
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
        BoxConfig.isolatedLazy(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
      );
}

extension CreateBoxFromConfigExtensions on BoxConfig {
  Box<K, T> box<K, T>() => Box<K, T>(this);
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
        BoxConfig(
          name,
          type: this,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
      );
}
