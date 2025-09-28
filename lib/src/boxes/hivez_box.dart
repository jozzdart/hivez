part of 'boxes.dart';

class HivezBox<K, T> extends AbstractHivezBox<K, T, Box<T>> {
  @override
  bool get isLazy => false;

  HivezBox(
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
    return _synchronizedRead(() => Future.value(hiveBox.values));
  }

  @override
  Future<T?> valueAt(int index) async {
    return _synchronizedRead(() => Future.value(hiveBox.getAt(index)));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _synchronizedRead(() async {
      for (final key in hiveBox.keys) {
        final value = hiveBox.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  Future<Map<K, T>> toMap() async {
    return _synchronizedRead(() => Future.value(hiveBox.toMap().cast<K, T>()));
  }

  @override
  Future<Box<T>> _ceateBoxInHive() {
    return Hive.openBox<T>(
      name,
      encryptionCipher: encryptionCipher,
      crashRecovery: crashRecovery,
      path: path,
      collection: collection,
    );
  }

  @override
  Box<T> _getBoxFromHive() => Hive.box<T>(name);
}
