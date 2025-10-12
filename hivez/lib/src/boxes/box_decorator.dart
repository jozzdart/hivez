part of 'boxes.dart';

/// {@template box_decorator}
/// A base decorator for [BoxInterface] implementations, enabling composition,
/// extension, and augmentation of box behaviors in a type-safe, production-grade manner.
///
/// The [BoxDecorator] class wraps an existing [BoxInterface] instance and delegates
/// all method calls and property accesses to the underlying box. This allows you to
/// transparently add cross-cutting concerns (such as logging, caching, access control,
/// or metrics) to any box type without modifying its implementation.
///
/// This pattern is especially useful for advanced scenarios where you want to
/// intercept, monitor, or enhance box operations in a modular and reusable way.
///
/// Type Parameters:
///   - [K]: The type of keys used in the box.
///   - [T]: The type of values stored in the box.
///
/// Example usage:
/// ```dart
/// class LoggingBox<K, T> extends BoxDecorator<K, T> {
///   LoggingBox(BoxInterface<K, T> box) : super(box);
///
///   @override
///   Future<void> put(K key, T value) async {
///     print('Putting key: $key, value: $value');
///     await super.put(key, value);
///   }
/// }
/// ```
///
/// See also:
/// - [BoxInterface] for the core box contract.
/// - [Box] for the main user-facing box abstraction.
/// {@endtemplate}
abstract class BoxDecorator<K, T> extends BoxInterface<K, T> {
  @override
  NativeBox<K, T> get _nativeBox => _internalBox._nativeBox;

  /// The underlying [BoxInterface] instance being decorated.
  final BoxInterface<K, T> _internalBox;

  /// Creates a [BoxDecorator] that wraps the given [_internalBox].
  ///
  /// All method calls and property accesses are delegated to [_internalBox].
  BoxDecorator(this._internalBox) : super(_internalBox.name);

  @override
  BoxType get boxType => _internalBox.boxType;

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
  Future<void> replaceAll(Map<K, T> entries) =>
      _internalBox.replaceAll(entries);
  @override
  Future<void> putAt(int index, T value) => _internalBox.putAt(index, value);

  @override
  Future<int> add(T value) => _internalBox.add(value);

  @override
  Future<Iterable<int>> addAll(Iterable<T> values) =>
      _internalBox.addAll(values);

  @override
  Future<bool> moveKey(K oldKey, K newKey) =>
      _internalBox.moveKey(oldKey, newKey);

  @override
  Future<void> delete(K key) => _internalBox.delete(key);
  @override
  Future<void> deleteAt(int index) => _internalBox.deleteAt(index);
  @override
  Future<void> deleteAtMany(Iterable<int> indices) =>
      _internalBox.deleteAtMany(indices);
  @override
  Future<void> deleteAll(Iterable<K> keys) => _internalBox.deleteAll(keys);
  @override
  Future<void> clear() => _internalBox.clear();

  @override
  Future<K?> keyAt(int index) => _internalBox.keyAt(index);

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
  Future<List<T>> getMany(Iterable<K> keys) => _internalBox.getMany(keys);

  @override
  Future<Iterable<T>> getAllValues() => _internalBox.getAllValues();
  @override
  Stream<BoxEvent> watch(K key) => _internalBox.watch(key);

  @override
  Future<List<T>> getValuesWhere(bool Function(T) condition) =>
      _internalBox.getValuesWhere(condition);

  @override
  Future<List<K>> getKeysWhere(bool Function(K key, T value) condition) =>
      _internalBox.getKeysWhere(condition);
  @override
  Future<T?> firstValueWhere(bool Function(K key, T value) condition) =>
      _internalBox.firstValueWhere(condition);
  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) =>
      _internalBox.firstWhereOrNull(condition);
  @override
  Future<T?> firstWhereContains(String query,
          {required String Function(T) searchableText}) =>
      _internalBox.firstWhereContains(query, searchableText: searchableText);

  @override
  Future<void> foreachValue(Future<void> Function(K, T) action,
          {bool Function()? breakCondition}) =>
      _internalBox.foreachValue(action, breakCondition: breakCondition);

  @override
  Future<void> foreachKey(Future<void> Function(K) action,
          {bool Function()? breakCondition}) =>
      _internalBox.foreachKey(action, breakCondition: breakCondition);

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
