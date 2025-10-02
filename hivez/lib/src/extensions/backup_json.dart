import 'dart:convert';

import 'package:hivez/src/boxes/boxes.dart';

/// Extension providing JSON backup and restore capabilities for [BoxInterface].
///
/// This extension enables any [BoxInterface] implementation to export its contents
/// as a JSON string and to restore its state from such a JSON backup. This is
/// useful for data migration, backup, and interoperability with other systems.
///
/// ## Example
/// ```dart
/// // Export box contents to JSON
/// final json = await box.generateBackupJson(
///   keyToString: (key) => key.toString(),
///   valueToJson: (value) => value.toJson(),
/// );
///
/// // Restore box contents from JSON
/// await box.restoreBackupJson(
///   json,
///   stringToKey: (str) => int.parse(str),
///   jsonToValue: (json) => MyModel.fromJson(json),
/// );
/// ```
extension BackupJsonExtension<K, T> on BoxInterface<K, T> {
  /// Generates a JSON string representing all key-value pairs in the box.
  ///
  /// - [keyToString]: Optional function to convert each key of type [K] to a [String].
  ///   If not provided, `key.toString()` is used.
  /// - [valueToJson]: Optional function to convert each value of type [T] to a JSON-serializable object.
  ///   If not provided, the value is used as-is (must be directly encodable by `jsonEncode`).
  ///
  /// Returns a [Future] that completes with the JSON string containing all box entries.
  ///
  /// Throws [BoxNotInitializedException] if the box is not initialized.
  Future<String> generateBackupJson({
    String Function(K key)? keyToString,
    Object? Function(T value)? valueToJson,
  }) async {
    await ensureInitialized();
    final keys = await getAllKeys();
    final Map<String, dynamic> data = {};

    for (final key in keys) {
      final value = await get(key);
      if (value != null) {
        final stringKey = keyToString?.call(key) ?? key.toString();
        final jsonValue = valueToJson?.call(value) ?? value;
        data[stringKey] = jsonValue;
      }
    }

    return jsonEncode(data);
  }

  /// Restores the box contents from a JSON string backup.
  ///
  /// - [json]: The JSON string representing the backup, as produced by [generateBackupJson].
  /// - [stringToKey]: Function to convert each string key in the JSON to a key of type [K].
  /// - [jsonToValue]: Function to convert each JSON value to a value of type [T].
  ///
  /// This method will:
  /// 1. Decode the JSON string into a map.
  /// 2. Convert each key and value using the provided functions.
  /// 3. Clear the box and insert all restored entries.
  ///
  /// Returns a [Future] that completes when the restore operation is finished.
  ///
  /// Throws [BoxNotInitializedException] if the box is not initialized.
  /// Throws [FormatException] if the JSON is invalid.
  Future<void> restoreBackupJson(
    String json, {
    required K Function(String key) stringToKey,
    required T Function(dynamic json) jsonToValue,
  }) async {
    await ensureInitialized();
    final Map<String, dynamic> decoded = jsonDecode(json);
    final Map<K, T> restored = {
      for (final entry in decoded.entries)
        stringToKey(entry.key): jsonToValue(entry.value)
    };
    await clear();
    await putAll(restored);
  }
}
