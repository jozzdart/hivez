import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

import '../core/core.dart';

class HivezIsolatedBox<K, T>
    extends AbstractHivezIsolatedBox<K, T, IsolatedBox<T>> {
  @override
  bool get isLazy => false;

  HivezIsolatedBox(
    super.boxName, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  @protected
  IsolatedBox<T> hiveGetBox() => IsolatedHive.box<T>(boxName);

  @override
  @protected
  Future<IsolatedBox<T>> hiveOpenBox() async => await IsolatedHive.openBox<T>(
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
    return synchronizedRead(() => box.values);
  }

  @override
  Future<T?> valueAt(int index) async {
    return synchronizedRead(() => box.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return synchronizedRead(() async {
      for (final key in (await box.keys)) {
        final value = await box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  Future<Map<K, T>> toMap() async {
    return synchronizedRead(
        () async => Future.value((await box.toMap()).cast<K, T>()));
  }
}
