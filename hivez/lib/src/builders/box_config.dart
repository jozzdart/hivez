// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'builders.dart';

enum BoxType {
  regular,
  lazy,
  isolated,
  isolatedLazy,
}

extension BoxInterfaceExtensions<K, T> on BoxInterface<K, T> {
  BoxType get type => switch (this) {
        HivezBox<K, T>() => BoxType.regular,
        HivezBoxLazy<K, T>() => BoxType.lazy,
        HivezBoxIsolated<K, T>() => BoxType.isolated,
        HivezBoxIsolatedLazy<K, T>() => BoxType.isolatedLazy,
        _ => throw Exception('Unknown box type'),
      };
}

class BoxConfig {
  final String name;
  final BoxType type;
  final HiveCipher? encryptionCipher;
  final bool crashRecovery;
  final String? path;
  final String? collection;
  final LogHandler? logger;
  const BoxConfig(
    this.name, {
    this.type = BoxType.regular,
    this.encryptionCipher,
    this.crashRecovery = true,
    this.path,
    this.collection,
    this.logger,
  });

  factory BoxConfig.regular(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(name,
          type: BoxType.regular,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger);

  factory BoxConfig.lazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(name,
          type: BoxType.lazy,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger);

  factory BoxConfig.isolated(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(name,
          type: BoxType.isolated,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger);

  factory BoxConfig.isolatedLazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
  }) =>
      BoxConfig(name,
          type: BoxType.isolatedLazy,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger);

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

extension BoxConfigExtensions on BoxConfig {
  BoxInterface<K, T> createBox<K, T>() => BoxCreator.boxFromConfig(this);

  ConfiguredBox<K, T> createConfiguredBox<K, T>() => ConfiguredBox(this);
}

extension CreationExtensionsBoxType on BoxType {
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
