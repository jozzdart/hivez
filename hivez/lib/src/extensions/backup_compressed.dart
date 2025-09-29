import 'dart:typed_data';
import 'package:hivez/hivez.dart';
import 'package:shrink/shrink.dart';

/// Extension providing compressed binary backup and restore capabilities for [BoxInterface].
///
/// This extension enables any [BoxInterface] implementation to export its contents
/// as a compressed binary blob (using the `shrink` package) and to restore its state
/// from such a compressed backup. This is useful for efficient storage, transfer,
/// and backup of box data, especially when dealing with large datasets or when
/// minimizing storage footprint is important.
///
/// ## Example
/// ```dart
/// // Export box contents to a compressed binary backup
/// final compressed = await box.generateBackupCompressed(
///   keyToString: (key) => key.toString(),
///   valueToJson: (value) => value.toJson(),
/// );
///
/// // Restore box contents from a compressed binary backup
/// await box.restoreBackupCompressed(
///   compressed,
///   stringToKey: (str) => int.parse(str),
///   jsonToValue: (json) => MyModel.fromJson(json),
/// );
/// ```
///
/// ## Details
/// - The backup is first serialized to JSON (see [generateBackupJson]), then compressed
///   using the `shrink` package to produce a [Uint8List].
/// - The restore process decompresses the binary data back to a JSON string, then
///   restores the box contents using [restoreBackupJson].
/// - This approach is compatible with any box whose keys and values can be serialized
///   to and from JSON.
///
/// See also:
/// - [generateBackupJson] and [restoreBackupJson] for JSON-based backup/restore.
/// - [shrink](https://pub.dev/packages/shrink) for compression details.
extension BackupCompressedExtension<K, T> on BoxInterface<K, T> {
  /// Generates a compressed binary backup ([Uint8List]) of all key-value pairs in the box.
  ///
  /// - [keyToString]: Optional function to convert each key of type [K] to a [String].
  ///   If not provided, `key.toString()` is used.
  /// - [valueToJson]: Optional function to convert each value of type [T] to a JSON-serializable object.
  ///   If not provided, the value is used as-is (must be directly encodable by `jsonEncode`).
  ///
  /// Returns a [Future] that completes with the compressed binary data representing all box entries.
  ///
  /// Throws [BoxNotInitializedException] if the box is not initialized.
  /// Throws any exception thrown by [generateBackupJson] or the compression process.
  Future<Uint8List> generateBackupCompressed({
    String Function(K key)? keyToString,
    Object? Function(T value)? valueToJson,
  }) async {
    // Generate a JSON string backup of the box contents.
    final json = await generateBackupJson(
      keyToString: keyToString,
      valueToJson: valueToJson,
    );
    // Compress the JSON string to a Uint8List using the shrink package.
    return json.shrink();
  }

  /// Restores the box contents from a compressed binary backup ([Uint8List]).
  ///
  /// - [data]: The compressed binary data representing the backup, as produced by [generateBackupCompressed].
  /// - [stringToKey]: Function to convert each string key in the JSON to a key of type [K].
  /// - [jsonToValue]: Function to convert each JSON value to a value of type [T].
  ///
  /// This method will:
  /// 1. Decompress the binary data to obtain the JSON string.
  /// 2. Decode the JSON and convert each key and value using the provided functions.
  /// 3. Clear the box and insert all restored entries.
  ///
  /// Returns a [Future] that completes when the restore operation is finished.
  ///
  /// Throws [BoxNotInitializedException] if the box is not initialized.
  /// Throws [FormatException] if the decompressed data is not valid JSON.
  /// Throws any exception thrown by [restoreBackupJson] or the decompression process.
  Future<void> restoreBackupCompressed(
    Uint8List data, {
    required K Function(String key) stringToKey,
    required T Function(dynamic json) jsonToValue,
  }) async {
    await ensureInitialized();
    final json = data.restoreText();
    return restoreBackupJson(
      json,
      stringToKey: stringToKey,
      jsonToValue: jsonToValue,
    );
  }
}
