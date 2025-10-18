import 'package:hivez/src/boxes/boxes.dart';
import 'hivez_hash_index_box.dart';
import 'package:synchronized/synchronized.dart';

class HivezEntityBox<T> extends BoxDecorator<int, T> {
  final Lock _lock = Lock();

  final HivezHashIndexBox hashIndexBox;

  final String Function(T item) hashFunction;
  final T Function(int newIndex, T item) assignIndex;

  HivezEntityBox(
    super._internalBox, {
    required this.hashFunction,
    required this.assignIndex,
  }) : hashIndexBox = HivezHashIndexBox(
          '${_internalBox.name}_hashed_index',
          type: _internalBox.boxType,
          path: _internalBox.path,
        );

  @override
  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    await hashIndexBox.ensureInitialized();
    await super.ensureInitialized();
  }

  @override
  Future<int> add(T value) => _lock.synchronized(() async {
        await ensureInitialized();
        return _add(value);
      });

  Future<int> _add(T value) async {
    final index = await hashIndexBox.getIndex(hashFunction(value));
    final itemWithIndex = assignIndex(index, value);
    await nativeBox.put(index, itemWithIndex);
    return index;
  }

  @override
  Future<List<int>> addAll(Iterable<T> values) => _lock.synchronized(() async {
        final indices = <int>[];
        for (final item in values) {
          final index = await _add(item);
          indices.add(index);
        }
        return indices;
      });

  Future<void> verifyItems() async {
    _lock.synchronized(() async {
      final hashes = <String>[];
      await foreachValue((key, value) async {
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
      await nativeBox.put(index, indexedNewItem);
      return true;
    });
  }

  @override
  Future<void> clear() async {
    await _lock.synchronized(() async {
      await super.clear();
      await hashIndexBox.clear();
    });
  }
}
