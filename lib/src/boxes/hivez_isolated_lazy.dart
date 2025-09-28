part of 'boxes.dart';

class HivezIsolatedLazyBox<K, T>
    extends AbstractHivezIsolatedBox<K, T, IsolatedLazyBox<T>> {
  @override
  bool get isLazy => true;

  HivezIsolatedLazyBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<IsolatedLazyBox<T>> _ceateBoxInHive() => IsolatedHive.openLazyBox<T>(
        name,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );

  @override
  IsolatedLazyBox<T> _getBoxFromHive() => IsolatedHive.lazyBox<T>(name);

  @override
  Future<T?> get(K key, {T? defaultValue}) async {
    return _synchronizedRead(
        () => Future.value(hiveBox.get(key, defaultValue: defaultValue)));
  }

  @override
  Future<Iterable<T>> getAllValues() async {
    return _synchronizedRead(() async {
      final keys = (await hiveBox.keys).cast<K>();
      final List<T> values = [];
      for (final key in keys) {
        final value = await hiveBox.get(key);
        if (value != null) values.add(value);
      }
      return values;
    });
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
}
