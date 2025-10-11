part of 'core.dart';

class NativeBoxConfig {
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

  /// Creates a new [BoxConfig] with the given parameters.
  ///
  /// [name] is required. All other parameters are optional and have sensible defaults.
  const NativeBoxConfig(
    this.name, {
    this.type = BoxType.regular,
    this.encryptionCipher,
    this.crashRecovery = true,
    this.path,
    this.collection,
  });

  /// Creates a [BoxConfig] for a regular (non-lazy, non-isolated) box.
  factory NativeBoxConfig.regular(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) =>
      NativeBoxConfig(
        name,
        type: BoxType.regular,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  /// Creates a [BoxConfig] for a lazy box.
  factory NativeBoxConfig.lazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) =>
      NativeBoxConfig(
        name,
        type: BoxType.lazy,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  /// Creates a [BoxConfig] for an isolated (background isolate) box.
  factory NativeBoxConfig.isolated(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) =>
      NativeBoxConfig(
        name,
        type: BoxType.isolated,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  /// Creates a [BoxConfig] for an isolated lazy box.
  factory NativeBoxConfig.isolatedLazy(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) =>
      NativeBoxConfig(
        name,
        type: BoxType.isolatedLazy,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  /// Returns a copy of this config with the given fields replaced.
  ///
  /// This is useful for creating modified variants of an existing config.
  NativeBoxConfig copyWith({
    String? name,
    BoxType? type,
    HiveCipher? encryptionCipher,
    bool? crashRecovery,
    String? path,
    String? collection,
  }) {
    return NativeBoxConfig(
      name ?? this.name,
      type: type ?? this.type,
      encryptionCipher: encryptionCipher ?? this.encryptionCipher,
      crashRecovery: crashRecovery ?? this.crashRecovery,
      path: path ?? this.path,
      collection: collection ?? this.collection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NativeBoxConfig &&
        other.name == name &&
        other.type == type &&
        other.encryptionCipher == encryptionCipher &&
        other.crashRecovery == crashRecovery &&
        other.path == path &&
        other.collection == collection;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      type.hashCode ^
      encryptionCipher.hashCode ^
      crashRecovery.hashCode ^
      path.hashCode ^
      collection.hashCode;

  @override
  String toString() =>
      'BoxConfig($name, $type, cRec: $crashRecovery, pth: $path, col: $collection)';
}
