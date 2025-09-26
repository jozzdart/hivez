import 'dart:convert';

import 'package:hivez/hivez.dart';

extension HivezBackupJsonExtension<K, T, B> on HivezBoxInterface<K, T, B> {
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
