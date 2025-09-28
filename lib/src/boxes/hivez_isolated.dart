part of 'boxes.dart';

class HivezIsolatedBox<K, T>
    extends AbstractHivezIsolatedBox<K, T, IsolatedBox<T>> {
  @override
  bool get isLazy => false;

  HivezIsolatedBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _synchronizedRead(
        () => Future.value(hiveBox.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _synchronizedRead(() => hiveBox.values);
  }

  @override
  Future<T?> valueAt(int index) async {
    return _synchronizedRead(() => hiveBox.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _synchronizedRead(() async {
      for (final key in (await hiveBox.keys)) {
        final value = await hiveBox.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  Future<Map<K, T>> toMap() async {
    return _synchronizedRead(
        () async => Future.value((await hiveBox.toMap()).cast<K, T>()));
  }

  @override
  Future<IsolatedBox<T>> _ceateBoxInHive() => IsolatedHive.openBox<T>(
        name,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  @override
  IsolatedBox<T> _getBoxFromHive() => IsolatedHive.box<T>(name);
}
