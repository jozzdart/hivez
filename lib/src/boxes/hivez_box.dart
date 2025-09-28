import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

import '../core/core.dart';

class HivezBox<K, T> extends AbstractHivezBox<K, T, Box<T>> {
  @override
  bool get isLazy => false;

  HivezBox(
    super.boxName, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  @protected
  Box<T> hiveGetBox() => Hive.box<T>(boxName);

  @override
  @protected
  Future<Box<T>> hiveOpenBox() async => await Hive.openBox<T>(
        boxName,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return synchronizedRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return synchronizedRead(() => Future.value(box.values));
  }

  @override
  Future<T?> valueAt(int index) async {
    return synchronizedRead(() => Future.value(box.getAt(index)));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return synchronizedRead(() async {
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  Future<Map<K, T>> toMap() async {
    return synchronizedRead(() => Future.value(box.toMap().cast<K, T>()));
  }
}
