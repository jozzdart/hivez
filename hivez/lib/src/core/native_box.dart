part of 'core.dart';

abstract class SharedBoxInterface<K, T> extends HiveBoxInterface<K, T> {
  /// The type of the native Hive box managed by this class.
  BoxType get boxType;

  @override
  final String name;

  const SharedBoxInterface(
    this.name, {
    /// The optional encryption cipher for securing box data.
    HiveCipher? encryptionCipher,

    /// Whether crash recovery is enabled for this box.
    bool crashRecovery = true,

    /// Optional custom storage path for the box.
    String? path,

    /// Optional logical collection name for grouping boxes.
    String? collection,
  });

  /// Whether the box has been initialized and is ready for operations.
  bool get isInitialized;

  /// Iterates asynchronously over all key-value pairs, invoking [action] for each.
  Future<void> foreachValue(Future<void> Function(K key, T value) action,
      {bool Function()? breakCondition});

  /// Iterates asynchronously over all keys, invoking [action] for each.
  Future<void> foreachKey(Future<void> Function(K key) action,
      {bool Function()? breakCondition});

  /// Moves the value from [oldKey] to [newKey], replacing any existing value.
  ///
  /// Returns `true` if the move was successful.
  Future<bool> moveKey(K oldKey, K newKey);

  /// Returns the values for the given [keys].
  Future<List<T>> getMany(Iterable<K> keys);

  /// Returns the values for the given [condition].
  Future<List<T>> getValuesWhere(bool Function(T) condition);

  /// Returns the keys for the given [condition].
  Future<List<K>> getKeysWhere(bool Function(K key, T value) condition);

  /// Returns the first key for the given [condition].
  Future<K?> firstKeyWhere(bool Function(K key, T value) condition);

  /// Returns the first value for the given [condition].
  ///
  /// Returns `null` if no value matches the condition.
  Future<T?> firstValueWhere(bool Function(K key, T value) condition);

  /// Returns approximate in-memory size (in bytes) of the entire box content.
  ///
  /// This includes keys and values, recursively traversing Maps, Lists,
  /// primitives, and strings. Does *not* include Hive metadata or file overhead.
  Future<int> estimateSizeBytes();

  /// Returns the first value matching [condition], or `null` if none found.
  Future<T?> firstWhereOrNull(bool Function(T item) condition);

  /// Returns the first value whose [searchableText] contains [query], or `null`.
  Future<T?> firstWhereContains(
    String query, {
    required String Function(T item) searchableText,
  });

  /// Replaces all data in the box with the given [entries].
  ///
  /// ⚠️ Note: This is a destructive operation — all existing data will be lost.
  Future<void> replaceAll(Map<K, T> entries);

  /// Deletes the values associated with the given [indices]. Faster than [deleteAt] for multiple indices.
  Future<void> deleteAtMany(Iterable<int> indices);

  /// Returns the key for the given [value], or `null` if not found.
  Future<K?> searchKeyOf(T value);
}

abstract class NativeBox<K, T> extends SharedBoxInterface<K, T> {
  /// The optional encryption cipher for securing box data.  /// The optional encryption cipher for securing box data.
  final HiveCipher? _encryptionCipher;

  /// Whether crash recovery is enabled for this box.
  final bool _crashRecovery;

  /// Optional custom storage path for the box.
  final String? _path;

  /// Optional logical collection name for grouping boxes.
  final String? _collection;

  const NativeBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  })  : _encryptionCipher = encryptionCipher,
        _crashRecovery = crashRecovery,
        _path = path,
        _collection = collection;

  String? get boxPath;

  Future<void> initialize();
  Future<void> boxClose();
  Future<void> boxDeleteFromDisk();
  Future<void> hiveDeleteBoxFromDisk();
  Future<void> hiveGetDeleteBoxFromDisk();

  bool get _boxIsOpen;
  bool get _isOpenInHive;
}

abstract class NativeBoxBase<K, T, B> extends NativeBox<K, T> {
  NativeBoxBase(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });

  @override
  bool get isInitialized => _box != null;

  @override
  String? get path => isInitialized ? boxPath : _path;

  B? _box;

  B get box {
    if (_box == null) {
      throw BoxNotInitializedException(
        boxName: name,
      );
    }
    return _box!;
  }

  @override
  bool get isOpen {
    if (_box == null) return false;
    return _boxIsOpen;
  }

  B _getExistingBox();

  Future<B> _openBox();

  @override
  Future<void> initialize() async =>
      _box = _isOpenInHive ? _getExistingBox() : await _openBox();

  @override
  Future<void> deleteFromDisk() async {
    if (isOpen) {
      await boxDeleteFromDisk();
    } else if (_isOpenInHive) {
      await hiveGetDeleteBoxFromDisk();
    } else {
      await hiveDeleteBoxFromDisk();
    }
    _box = null;
  }

  @override
  Future<void> closeBox() async {
    if (isOpen) {
      await boxClose();
      _box = null;
    }
  }

  @override
  Future<int> estimateSizeBytes() async {
    int total = 0;
    await foreachValue((k, v) async {
      total += _estimateAny(k) + _estimateAny(v);
    });
    return total;
  }

  static int _estimateAny(dynamic obj) {
    if (obj == null) return 0;
    if (obj is num || obj is bool) return 8;
    if (obj is String) return utf8.encode(obj).length;
    if (obj is List) {
      return obj.fold<int>(0, (sum, e) => sum + _estimateAny(e));
    }
    if (obj is Map) {
      return obj.entries.fold<int>(
        0,
        (sum, e) => sum + _estimateAny(e.key) + _estimateAny(e.value),
      );
    }
    try {
      return utf8.encode(obj.toString()).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> foreachKey(Future<void> Function(K key) action,
      {bool Function()? breakCondition}) async {
    final keys = await getAllKeys();
    for (final key in keys) {
      await action(key);
      if (breakCondition != null && breakCondition()) {
        return;
      }
    }
  }

  @override
  Future<void> foreachValue(Future<void> Function(K key, T value) action,
      {bool Function()? breakCondition}) async {
    await foreachKey((key) async {
      final value = await get(key);
      if (value != null) {
        await action(key, value);
      }
    }, breakCondition: breakCondition);
  }

  @override
  Future<List<T>> getValuesWhere(bool Function(T value) condition) async {
    final values = <T>[];
    await foreachValue((k, v) async {
      if (condition(v)) {
        values.add(v);
      }
    });
    return values;
  }

  @override
  Future<List<K>> getKeysWhere(bool Function(K key, T value) condition) async {
    final keys = <K>[];
    await foreachValue((k, v) async {
      if (v != null && condition(k, v)) {
        keys.add(k);
      }
    });
    return keys;
  }

  @override
  Future<K?> firstKeyWhere(bool Function(K key, T value) condition) async {
    final keys = await getAllKeys();
    for (final key in keys) {
      final v = await get(key);
      if (v != null && condition(key, v)) {
        return key;
      }
    }
    return null;
  }

  @override
  Future<T?> firstValueWhere(bool Function(K key, T value) condition) async {
    final keys = await getAllKeys();
    for (final key in keys) {
      final v = await get(key);
      if (v != null && condition(key, v)) {
        return v;
      }
    }
    return null;
  }

  @override
  Future<T?> firstWhereContains(
    String query, {
    required String Function(T item) searchableText,
  }) {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return Future.value(null);

    return firstWhereOrNull(
      (item) => searchableText(item).toLowerCase().contains(lowerQuery),
    );
  }

  @override
  Future<T?> firstWhereOrNull(bool Function(T) condition) async {
    for (final key in (await getAllKeys())) {
      final value = await get(key);
      if (value != null && condition(value)) return value;
    }
    return null;
  }

  @override
  Future<List<T>> getMany(Iterable<K> keys) async {
    final values = <T>[];
    for (final key in keys) {
      final value = await get(key);
      if (value != null) values.add(value);
    }
    return values;
  }

  @override
  Future<bool> moveKey(K oldKey, K newKey) async {
    final oldValue = await get(oldKey);
    if (oldValue == null) {
      return false;
    }

    await put(newKey, oldValue);
    await delete(oldKey);

    return true;
  }

  @override
  Future<void> replaceAll(Map<K, T> entries) async {
    await clear();
    await putAll(entries);
  }

  @override
  Future<void> deleteAtMany(Iterable<int> indices) async {
    for (final index in indices) {
      await deleteAt(index);
    }
  }

  @override
  Future<K?> searchKeyOf(T value) => firstKeyWhere((k, v) => v == value);
}

abstract class NativeBoxNonIsolatedBase<K, T, B extends BoxBase<T>>
    extends NativeBoxBase<K, T, B> {
  NativeBoxNonIsolatedBase(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });
  @override
  bool get isIsolated => false;

  @override
  Future<bool> get isEmpty => Future.value(box.isEmpty);

  @override
  Future<bool> get isNotEmpty => Future.value(box.isNotEmpty);

  @override
  Future<int> get length => Future.value(box.length);

  @override
  String? get boxPath => box.path;

  @override
  Future<void> boxDeleteFromDisk() => box.deleteFromDisk();

  @override
  Future<void> hiveDeleteBoxFromDisk() => Hive.deleteBoxFromDisk(name);

  @override
  Future<void> hiveGetDeleteBoxFromDisk() => _getExistingBox().deleteFromDisk();

  @override
  Future<void> put(K key, T value) => box.put(key, value);

  @override
  Future<void> putAll(Map<K, T> entries) => box.putAll(entries);

  @override
  Future<void> putAt(int index, T value) => box.putAt(index, value);

  @override
  Future<void> delete(K key) => box.delete(key);

  @override
  Future<void> deleteAt(int index) => box.deleteAt(index);

  @override
  Future<void> deleteAll(Iterable<K> keys) => box.deleteAll(keys);

  @override
  Future<void> clear() => box.clear();

  @override
  Future<bool> containsKey(K key) => Future.value(box.containsKey(key));

  @override
  Future<Iterable<K>> getAllKeys() => Future.value(box.keys.cast<K>());

  @override
  Future<int> add(T value) => box.add(value);

  @override
  Future<Iterable<int>> addAll(Iterable<T> values) => box.addAll(values);

  @override
  Future<K?> keyAt(int index) {
    final key = box.keyAt(index);
    return Future.value(key as K?);
  }

  @override
  Future<void> flushBox() => box.flush();

  @override
  Future<void> compactBox() => box.compact();

  @override
  Stream<BoxEvent> watch(K key) => box.watch(key: key);

  @override
  bool get _isOpenInHive => Hive.isBoxOpen(name);

  @override
  bool get _boxIsOpen => box.isOpen;

  @override
  Future<void> boxClose() => box.close();
}

abstract class NativeBoxIsolatedBase<K, T, B extends IsolatedBoxBase<T>>
    extends NativeBoxBase<K, T, B> {
  NativeBoxIsolatedBase(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });

  @override
  bool get isIsolated => true;

  @override
  Future<bool> get isEmpty => box.isEmpty;

  @override
  Future<bool> get isNotEmpty => box.isNotEmpty;

  @override
  Future<int> get length => box.length;

  @override
  String? get boxPath => _path;

  @override
  Future<void> boxDeleteFromDisk() => box.deleteFromDisk();

  @override
  Future<void> hiveDeleteBoxFromDisk() => IsolatedHive.deleteBoxFromDisk(name);

  @override
  Future<void> hiveGetDeleteBoxFromDisk() => _getExistingBox().deleteFromDisk();

  @override
  Future<void> put(K key, T value) => box.put(key, value);

  @override
  Future<void> putAll(Map<K, T> entries) => box.putAll(entries);

  @override
  Future<void> putAt(int index, T value) => box.putAt(index, value);

  @override
  Future<void> delete(K key) => box.delete(key);

  @override
  Future<void> deleteAt(int index) => box.deleteAt(index);

  @override
  Future<void> deleteAll(Iterable<K> keys) => box.deleteAll(keys);

  @override
  Future<void> clear() async => box.clear();

  @override
  Future<bool> containsKey(K key) => box.containsKey(key);

  @override
  Future<Iterable<K>> getAllKeys() async => (await box.keys).cast<K>();

  @override
  Future<int> add(T value) => box.add(value);

  @override
  Future<Iterable<int>> addAll(Iterable<T> values) => box.addAll(values);

  @override
  Future<K?> keyAt(int index) async {
    final key = await box.keyAt(index);
    return key as K?;
  }

  @override
  Future<void> flushBox() => box.flush();

  @override
  Future<void> compactBox() => box.compact();

  @override
  Stream<BoxEvent> watch(K key) => box.watch(key: key);

  @override
  bool get _isOpenInHive => IsolatedHive.isBoxOpen(name);

  @override
  bool get _boxIsOpen => box.isOpen;

  @override
  Future<void> boxClose() => box.close();

  @override
  Future<T?> get(K key, {T? defaultValue}) =>
      box.get(key, defaultValue: defaultValue);

  @override
  Future<T?> getAt(int index) => box.getAt(index);

  @override
  Future<Iterable<T>> getAllValues() async {
    final keys = await box.keys;
    final values = <T>[];
    for (final key in keys) {
      final value = await box.get(key);
      if (value != null) values.add(value);
    }
    return values;
  }

  @override
  Future<Map<K, T>> toMap() async {
    final keys = await box.keys;
    final Map<K, T> map = {};
    for (final key in keys) {
      final value = await box.get(key);
      if (value != null) map[key] = value;
    }
    return map;
  }
}

class NativeBoxImpl<K, T> extends NativeBoxNonIsolatedBase<K, T, Box<T>> {
  NativeBoxImpl(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });

  @override
  bool get isLazy => false;

  @override
  BoxType get boxType => BoxType.regular;

  @override
  Box<T> _getExistingBox() => Hive.box<T>(name);

  @override
  Future<Box<T>> _openBox() => Hive.openBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );

  @override
  Future<T?> get(K key, {T? defaultValue}) =>
      Future.value(box.get(key, defaultValue: defaultValue));

  @override
  Future<Iterable<T>> getAllValues() => Future.value(box.values);

  @override
  Future<T?> getAt(int index) => Future.value(box.getAt(index));

  @override
  Future<Map<K, T>> toMap() => Future.value(box.toMap().cast<K, T>());
}

class NativeBoxLazyImpl<K, T>
    extends NativeBoxNonIsolatedBase<K, T, LazyBox<T>> {
  NativeBoxLazyImpl(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });

  @override
  bool get isLazy => true;

  @override
  BoxType get boxType => BoxType.lazy;

  @override
  LazyBox<T> _getExistingBox() => Hive.lazyBox<T>(name);

  @override
  Future<LazyBox<T>> _openBox() => Hive.openLazyBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );

  @override
  Future<T?> get(K key, {T? defaultValue}) =>
      box.get(key, defaultValue: defaultValue);

  @override
  Future<T?> getAt(int index) => box.getAt(index);

  @override
  Future<Iterable<T>> getAllValues() async {
    final keys = box.keys;
    final values = <T>[];
    for (final key in keys) {
      final value = await box.get(key);
      if (value != null) values.add(value);
    }
    return values;
  }

  @override
  Future<Map<K, T>> toMap() async {
    final keys = box.keys;
    final Map<K, T> map = {};
    for (final key in keys) {
      final value = await box.get(key);
      if (value != null) map[key] = value;
    }
    return map;
  }
}

class NativeBoxIsolatedImpl<K, T>
    extends NativeBoxIsolatedBase<K, T, IsolatedBox<T>> {
  NativeBoxIsolatedImpl(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });

  @override
  bool get isLazy => false;
  @override
  BoxType get boxType => BoxType.isolated;
  @override
  IsolatedBox<T> _getExistingBox() => IsolatedHive.box<T>(name);

  @override
  Future<IsolatedBox<T>> _openBox() => IsolatedHive.openBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );
}

class NativeBoxIsolatedLazyImpl<K, T>
    extends NativeBoxIsolatedBase<K, T, IsolatedLazyBox<T>> {
  NativeBoxIsolatedLazyImpl(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
  });

  @override
  bool get isLazy => true;

  @override
  BoxType get boxType => BoxType.isolatedLazy;

  @override
  IsolatedLazyBox<T> _getExistingBox() => IsolatedHive.lazyBox<T>(name);

  @override
  Future<IsolatedLazyBox<T>> _openBox() => IsolatedHive.openLazyBox<T>(
        name,
        encryptionCipher: _encryptionCipher,
        crashRecovery: _crashRecovery,
        path: _path,
        collection: _collection,
      );
}
