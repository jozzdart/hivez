import 'package:hivez/hivez.dart';
import 'package:hivez/src/boxes/boxes.dart';
import 'package:synchronized/synchronized.dart';

class HivezHashIndexBox extends Box<String, int> {
  static const String _indexKey = 'index';

  final Lock _lock = Lock();

  HivezHashIndexBox(
    super.name, {
    super.type,
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  factory HivezHashIndexBox.fromConfig(BoxConfig config) => HivezHashIndexBox(
        config.name,
        type: config.type,
        encryptionCipher: config.encryptionCipher,
        crashRecovery: config.crashRecovery,
        path: config.path,
        collection: config.collection,
        logger: config.logger,
      );

  @override
  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    await super.ensureInitialized();
    final hasIndex = await nativeBox.containsKey(_indexKey);
    if (!hasIndex) {
      await nativeBox.put(_indexKey, 1);
    }
  }

  /// Returns the ID for a given hash.
  /// If the hash is not yet in the DB, assigns it a new ID.
  Future<int> getIndex(String hash) => _lock.synchronized(() async {
        await ensureInitialized();

        final existing = await nativeBox.get(hash);
        if (existing != null) return existing;

        final currentIndex = await nativeBox.get(_indexKey) ?? 1;
        await nativeBox.put(hash, currentIndex);
        await nativeBox.put(_indexKey, currentIndex + 1);

        return currentIndex;
      });

  Future<int?> renameHash(String oldHash, String newHash) =>
      _lock.synchronized(() async {
        await ensureInitialized();

        // Get the ID associated with the old hash
        final index = await nativeBox.get(oldHash);
        if (index == null) {
          return null; // Old hash doesn't exist
        }

        // Check if new hash already exists
        final existingId = await nativeBox.get(newHash);
        if (existingId != null) {
          return null; // New hash already exists with a different ID
        }

        // Add the new hash with the same ID
        await nativeBox.put(newHash, index);

        // Remove the old hash
        await nativeBox.delete(oldHash);

        return index;
      });

  /// Returns the current max index without modifying anything
  Future<int> getCurrentIndex() async => await get(_indexKey) ?? 1;

  @override
  Future<void> clear() => _lock.synchronized(() async {
        await ensureInitialized();
        await nativeBox.clear();
        await nativeBox.put(_indexKey, 1);
      });

  Future<bool> containsHash(String hash) => containsKey(hash);

  Future<int?> tryGetIndex(String hash) => get(hash);

  Future<void> verifyHashes(List<String> allowedHashes) =>
      _lock.synchronized(() async {
        await ensureInitialized();

        final allKeys = await nativeBox.getAllKeys();
        final Set<String> allowedSet = allowedHashes.toSet();

        final keysToDelete = allKeys.where((key) {
          return key != _indexKey && !allowedSet.contains(key);
        });

        if (keysToDelete.isNotEmpty) {
          await nativeBox.deleteAll(keysToDelete);
        }
      });

  Future<String> generateBackup() => generateBackupJson(
        keyToString: (key) => key,
        valueToJson: (value) => value.toString(),
      );

  Future<void> restoreBackup(String json) => restoreBackupJson(
        json,
        stringToKey: (k) => k,
        jsonToValue: (v) => int.parse(v),
      );
}
