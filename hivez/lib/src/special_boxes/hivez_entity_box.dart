import 'package:hivez/src/boxes/boxes.dart';
import 'hivez_hash_index_box.dart';
import 'package:synchronized/synchronized.dart';

class HivezEntityBox<T> {
  final Lock _lock = Lock();
  final Lock _additionalLock = Lock();

  final BoxInterface<int, T> dataBox;
  final HivezHashIndexBox hashIndexBox;

  final String Function(T item) hashFunction;
  final T Function(int newIndex, T item) assignIndex;

  HivezEntityBox({
    required this.dataBox,
    required this.hashIndexBox,
    required this.hashFunction,
    required this.assignIndex,
  });

  Future<void> ensureInitialized() async {
    await hashIndexBox.hashBox.ensureInitialized();
    await dataBox.ensureInitialized();
  }

  Future<int> get length async => await dataBox.length;

  Future<int> addItem(T item) async {
    return await _lock.synchronized(() async {
      await ensureInitialized();
      final index = await hashIndexBox.getIndex(hashFunction(item));
      final itemWithIndex = assignIndex(index, item);
      await dataBox.put(index, itemWithIndex);
      return index;
    });
  }

  Future<void> addMultipleItems(List<T> items) async {
    await _additionalLock.synchronized(() async {
      for (final item in items) {
        await addItem(item);
      }
    });
  }

  Future<void> verifyItems() async {
    _lock.synchronized(() async {
      final hashes = <String>[];
      await dataBox.foreachValue((key, value) async {
        hashes.add(hashFunction(value));
      });

      await hashIndexBox.verifyHashes(hashes);
    });
  }

  Future<bool> replaceItem(T oldItem, T newItem) async {
    return _lock.synchronized(() async {
      await ensureInitialized();
      final oldHash = hashFunction(oldItem);
      final newHash = hashFunction(newItem);

      final index = await hashIndexBox.renameHash(oldHash, newHash);
      if (index == null) {
        return false;
      }

      final indexedNewItem = assignIndex(index, newItem);
      await dataBox.put(index, indexedNewItem);
      return true;
    });
  }

  Future<void> clear() async {
    await _lock.synchronized(() async {
      await dataBox.clear();
      await hashIndexBox.clear();
    });
  }
}
