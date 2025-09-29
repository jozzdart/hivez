import 'dart:typed_data';
import 'package:hivez/hivez.dart';
import 'package:shrink/shrink.dart';

extension BackupCompressedExtension<K, T> on BoxInterface<K, T> {
  Future<Uint8List> generateBackupCompressed({
    String Function(K key)? keyToString,
    Object? Function(T value)? valueToJson,
  }) async {
    final json = await generateBackupJson(
      keyToString: keyToString,
      valueToJson: valueToJson,
    );
    return json.shrink();
  }

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
