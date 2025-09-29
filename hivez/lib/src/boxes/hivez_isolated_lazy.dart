part of 'boxes.dart';

class HivezBoxIsolatedLazy<K, T>
    extends AbstractHivezIsolatedBox<K, T, IsolatedLazyBox<T>> {
  @override
  bool get isLazy => true;

  HivezBoxIsolatedLazy(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<IsolatedLazyBox<T>> _openBox() => IsolatedHive.openLazyBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );

  @override
  IsolatedLazyBox<T> _getExistingBox() => IsolatedHive.lazyBox<T>(name);

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _executeRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _executeRead(() async {
      final keys = (await box.keys).cast<K>();
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
}
