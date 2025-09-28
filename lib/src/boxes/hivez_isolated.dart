part of 'boxes.dart';

class HivezBoxIsolated<K, T>
    extends AbstractHivezIsolatedBox<K, T, IsolatedBox<T>> {
  @override
  bool get isLazy => false;

  HivezBoxIsolated(
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
    return _executeRead(() => box.values);
  }

  @override
  Future<T?> valueAt(int index) async {
    return _executeRead(() => box.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _executeRead(() async {
      for (final key in (await box.keys)) {
        final value = await box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }

  Future<Map<K, T>> toMap() async {
    return _executeRead(
        () async => Future.value((await box.toMap()).cast<K, T>()));
  }

  @override
  Future<IsolatedBox<T>> _openBox() => IsolatedHive.openBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );

  @override
  IsolatedBox<T> _getExistingBox() => IsolatedHive.box<T>(name);
}
