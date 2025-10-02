import 'package:hivez/hivez.dart';
import 'package:synchronized/synchronized.dart';

class HivezHashIndexBox<BI extends BoxInterface<String, int>> {
  static const String _indexKey = 'index';

  BI get hashBox => _internalBox;
  final BI _internalBox;
  final Lock _lock = Lock();

  HivezHashIndexBox(this._internalBox);

  Future<void> init() async {
    await _internalBox.ensureInitialized();
    final hasIndex = await _internalBox.containsKey(_indexKey);
    if (!hasIndex) {
      await _internalBox.put(_indexKey, 1);
    }
  }

  /// Returns the ID for a given hash.
  /// If the hash is not yet in the DB, assigns it a new ID.
  Future<int> getIndex(String hash) async {
    return _lock.synchronized(() async {
      await _internalBox.ensureInitialized();

      final existing = await _internalBox.get(hash);
      if (existing != null) return existing;

      final currentIndex = await _internalBox.get(_indexKey) ?? 1;
      await _internalBox.put(hash, currentIndex);
      await _internalBox.put(_indexKey, currentIndex + 1);

      return currentIndex;
    });
  }

  Future<int?> renameHash(String oldHash, String newHash) async {
    await _internalBox.ensureInitialized();

    return _lock.synchronized(() async {
      // Get the ID associated with the old hash
      final index = await _internalBox.get(oldHash);
      if (index == null) {
        return null; // Old hash doesn't exist
      }

      // Check if new hash already exists
      final existingId = await _internalBox.get(newHash);
      if (existingId != null) {
        return null; // New hash already exists with a different ID
      }

      // Add the new hash with the same ID
      await _internalBox.put(newHash, index);

      // Remove the old hash
      await _internalBox.delete(oldHash);

      return index;
    });
  }

  /// Returns the current max index without modifying anything
  Future<int> getCurrentIndex() async {
    await _internalBox.ensureInitialized();
    return (await _internalBox.get(_indexKey)) ?? 1;
  }

  /// Clears everything, including the index
  Future<void> clear() async {
    await _internalBox.clear();
    await _internalBox.put(_indexKey, 1);
  }

  Future<bool> containsHash(String hash) async {
    return _internalBox.containsKey(hash);
  }

  Future<int?> tryGetIndex(String hash) async {
    return _internalBox.get(hash);
  }

  Future<void> verifyHashes(List<String> allowedHashes) async {
    await _lock.synchronized(() async {
      await _internalBox.ensureInitialized();

      final allKeys = await _internalBox.getAllKeys();
      final Set<String> allowedSet = allowedHashes.toSet();

      final keysToDelete = allKeys.where((key) {
        return key != _indexKey && !allowedSet.contains(key);
      });

      if (keysToDelete.isNotEmpty) {
        await _internalBox.deleteAll(keysToDelete);
      }
    });
  }

  Future<String> generateBackup() async {
    return _internalBox.generateBackupJson(
      keyToString: (key) => key,
      valueToJson: (value) => value.toString(),
    );
  }

  Future<void> restoreBackup(String json) async {
    await _internalBox.restoreBackupJson(
      json,
      stringToKey: (k) => k,
      jsonToValue: (v) => int.parse(v),
    );
  }
}
