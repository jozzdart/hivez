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
    return _executeRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _executeRead(() => Future.value(box.values));
  }

  @override
  Future<T?> valueAt(int index) async {
    return _executeRead(() => Future.value(box.getAt(index)));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _executeRead(() async {
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  Future<Map<K, T>> toMap() async {
    return _executeRead(() => Future.value(box.toMap().cast<K, T>()));
  }

  @override
  Future<Box<T>> _openBox() {
    return Hive.openBox<T>(
      name,
      encryptionCipher: _encryptionCipher,
      crashRecovery: _crashRecovery,
      path: _path,
      collection: _collection,
    );
  }

  @override
  Box<T> _getExistingBox() => Hive.box<T>(name);
}
