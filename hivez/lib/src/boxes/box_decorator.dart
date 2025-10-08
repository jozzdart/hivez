part of 'boxes.dart';

abstract class BoxDecorator<K, T> extends BoxInterface<K, T> {
  final BoxInterface<K, T> _internalBox;

  BoxDecorator(this._internalBox)
      : super(
          _internalBox.name,
          encryptionCipher: _internalBox._encryptionCipher,
          crashRecovery: _internalBox._crashRecovery,
          path: _internalBox.path,
          collection: _internalBox._collection,
        );

  @override
  bool get isOpen => _internalBox.isOpen;
  @override
  bool get isInitialized => _internalBox.isInitialized;
  @override
  bool get isIsolated => _internalBox.isIsolated;
  @override
  bool get isLazy => _internalBox.isLazy;
  @override
  String? get path => _internalBox.path;

  @override
  Future<void> ensureInitialized() => _internalBox.ensureInitialized();
  @override
  Future<void> deleteFromDisk() => _internalBox.deleteFromDisk();
  @override
  Future<void> closeBox() => _internalBox.closeBox();
  @override
  Future<void> flushBox() => _internalBox.flushBox();
  @override
  Future<void> compactBox() => _internalBox.compactBox();

  @override
  Future<bool> get isEmpty => _internalBox.isEmpty;
  @override
  Future<bool> get isNotEmpty => _internalBox.isNotEmpty;
  @override
  Future<int> get length => _internalBox.length;

  @override
  Future<void> put(K key, T value) => _internalBox.put(key, value);
  @override
  Future<void> putAll(Map<K, T> entries) => _internalBox.putAll(entries);
  @override
  Future<void> putAt(int index, T value) => _internalBox.putAt(index, value);
  @override
  Future<int> add(T value) => _internalBox.add(value);
  @override
  Future<void> addAll(Iterable<T> values) => _internalBox.addAll(values);
  @override
  Future<bool> moveKey(K oldKey, K newKey) =>
      _internalBox.moveKey(oldKey, newKey);

  @override
  Future<void> delete(K key) => _internalBox.delete(key);
  @override
  Future<void> deleteAt(int index) => _internalBox.deleteAt(index);
  @override
  Future<void> deleteAll(Iterable<K> keys) => _internalBox.deleteAll(keys);
  @override
  Future<void> clear() => _internalBox.clear();

  @override
  Future<K> keyAt(int index) => _internalBox.keyAt(index);
  @override
  Future<T?> valueAt(int index) => _internalBox.valueAt(index);
  @override
  Future<T?> getAt(int index) => _internalBox.getAt(index);
  @override
  Future<bool> containsKey(K key) => _internalBox.containsKey(key);
  @override
  Future<Iterable<K>> getAllKeys() => _internalBox.getAllKeys();
  @override
  Future<T?> get(K key, {T? defaultValue}) =>
      _internalBox.get(key, defaultValue: defaultValue);
  @override
  Future<Iterable<T>> getAllValues() => _internalBox.getAllValues();
  @override
  Stream<BoxEvent> watch(K key) => _internalBox.watch(key);

  @override
  Future<Iterable<T>> getValuesWhere(bool Function(T) condition) =>
      _internalBox.getValuesWhere(condition);

  @override
  Future<Iterable<K>> getKeysWhere(bool Function(K key, T value) condition) =>
      _internalBox.getKeysWhere(condition);

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) =>
      _internalBox.firstWhereOrNull(condition);
  @override
  Future<T?> firstWhereContains(String query,
          {required String Function(T) searchableText}) =>
      _internalBox.firstWhereContains(query, searchableText: searchableText);

  @override
  Future<void> foreachValue(Future<void> Function(K, T) action) =>
      _internalBox.foreachValue(action);
  @override
  Future<void> foreachKey(Future<void> Function(K) action) =>
      _internalBox.foreachKey(action);

  @override
  Future<K?> firstKeyWhere(bool Function(K key, T value) condition) =>
      _internalBox.firstKeyWhere(condition);

  @override
  Future<K?> searchKeyOf(T value) => _internalBox.searchKeyOf(value);

  @override
  Future<int> estimateSizeBytes() => _internalBox.estimateSizeBytes();

  @override
  bool operator ==(Object other) =>
      other is BoxDecorator<K, T> && other._internalBox == _internalBox;

  @override
  int get hashCode => _internalBox.hashCode;

  @override
  String toString() => _stringBox('BoxDecorator', this);

  @override
  Future<Map<K, T>> toMap() => _internalBox.toMap();
}
