import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

import '../core/core.dart';

class HivezLazyBox<K, T> extends AbstractHivezBox<K, T, LazyBox<T>> {
  @override
  bool get isLazy => true;

  HivezLazyBox(
    super.boxName, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  @protected
  LazyBox<T> hiveGetBox() => Hive.lazyBox<T>(boxName);

  @override
  @protected
  Future<LazyBox<T>> hiveOpenBox() async => await Hive.openLazyBox<T>(
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
    return synchronizedRead(() async {
      final keys = box.keys.cast<K>();
      final List<T> values = [];
      for (final key in keys) {
        final value = await box.get(key);
        if (value != null) values.add(value);
      }
      return values;
    });
  }

  @override
  Future<T?> valueAt(int index) async {
    return synchronizedRead(() => box.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return synchronizedRead(() async {
      for (final key in box.keys) {
        final value = await box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }
}
