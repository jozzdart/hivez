part of 'boxes.dart';

class HivezLazyBox<K, T> extends AbstractHivezBox<K, T, LazyBox<T>> {
  @override
  bool get isLazy => true;

  HivezLazyBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<LazyBox<T>> _openBox() => Hive.openLazyBox<T>(
        name,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  @override
  LazyBox<T> _getExistingBox() => Hive.lazyBox<T>(name);

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _executeRead(
        () => Future.value(box.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _executeRead(() async {
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
    return _executeRead(() => box.getAt(index));
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    return _executeRead(() async {
      for (final key in box.keys) {
        final value = await box.get(key);
        if (value != null && condition(value)) return value;
      }
      return null;
    });
  }
}
