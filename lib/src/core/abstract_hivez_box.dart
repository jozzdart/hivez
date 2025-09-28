import 'package:hive_ce/hive.dart';

import 'base_box.dart';

abstract class AbstractHivezBox<K, T, B extends BoxBase<T>>
    extends BaseHivezBox<K, T, B> {
  @override
  bool get isIsolated => false;

  AbstractHivezBox(
    super.boxName, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<void> put(K key, T value) async {
    await synchronizedWrite(() => box.put(key, value));
  }

  @override
  Future<void> putAll(Map<K, T> entries) async {
    await synchronizedWrite(() => box.putAll(entries));
  }

  @override
  Future<void> putAt(int index, T value) async {
    await synchronizedWrite(() => box.putAt(index, value));
  }

  @override
  Future<void> delete(K key) async {
    await synchronizedWrite(() => box.delete(key));
  }

  @override
  Future<void> deleteAt(int index) async {
    await synchronizedWrite(() => box.deleteAt(index));
  }

  @override
  Future<void> deleteAll(Iterable<K> keys) async {
    await synchronizedWrite(() => box.deleteAll(keys));
  }

  @override
  Future<void> clear() async {
    await synchronizedWrite(() => box.clear());
  }

  @override
  Future<bool> containsKey(K key) async {
    return synchronizedRead(() => Future.value(box.containsKey(key)));
  }

  @override
  Future<int> get length async {
    return synchronizedRead(() => Future.value(box.length));
  }

  @override
  Future<Iterable<K>> getAllKeys() async {
    return synchronizedRead(() => Future.value(box.keys.cast<K>()));
  }

  @override
  Future<int> add(T value) async {
    return synchronizedWrite(() => box.add(value));
  }

  @override
  Future<void> addAll(Iterable<T> values) async {
    return synchronizedWrite(() => box.addAll(values));
  }

  @override
  Future<K> keyAt(int index) async {
    return synchronizedRead(() => Future.value(box.keyAt(index) as K));
  }

  @override
  Future<bool> get isEmpty async {
    return synchronizedRead(() => Future.value(box.isEmpty));
  }

  @override
  Future<bool> get isNotEmpty async {
    return synchronizedRead(() => Future.value(box.isNotEmpty));
  }

  @override
  Future<void> flushBox() async {
    await synchronizedWrite(() => box.flush());
  }

  @override
  Future<void> compactBox() async {
    await synchronizedWrite(() => box.compact());
  }

  @override
  Stream<BoxEvent> watch(K key) {
    return box.watch(key: key);
  }

  @override
  Future<void> closeBox() async {
    if (isOpen) {
      await box.close();
      await super.closeBox();
    }
  }

  @override
  Future<void> deleteFromDisk() async {
    if (isOpen) {
      await box.deleteFromDisk();
    } else if (Hive.isBoxOpen(boxName)) {
      await hiveGetBox().deleteFromDisk();
    } else {
      await Hive.deleteBoxFromDisk(boxName);
    }
    await super.deleteFromDisk();
  }
}
