part of 'boxes.dart';

typedef LogHandler = void Function(String message);

abstract class BoxInterface<K, T, BoxType> {
  final String name;
  final HiveCipher? _encryptionCipher;
  final bool _crashRecovery;
  final String? _path;
  final String? _collection;

  BoxInterface(
    this.name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
  })  : _encryptionCipher = encryptionCipher,
        _crashRecovery = crashRecovery,
        _path = path,
        _collection = collection,
        assert(name.isNotEmpty, 'Box name cannot be empty');

  bool get isOpen;
  bool get isInitialized;
  bool get isIsolated;
  bool get isLazy;

  BoxType get box;
  String? get path;

  Future<bool> get isEmpty;
  Future<bool> get isNotEmpty;
  Future<int> get length;

  // Write operations
  Future<void> put(K key, T value);
  Future<void> putAll(Map<K, T> entries);
  Future<void> putAt(int index, T value);
  Future<int> add(T value);
  Future<void> addAll(Iterable<T> values);
  Future<bool> moveKey(K oldKey, K newKey);

  // Delete operations
  Future<void> delete(K key);
  Future<void> deleteAt(int index);
  Future<void> deleteAll(Iterable<K> keys);
  Future<void> clear();

  // Read operations
  Future<K> keyAt(int index);
  Future<T?> valueAt(int index);
  Future<T?> getAt(int index);
  Future<bool> containsKey(K key);
  Future<Iterable<K>> getAllKeys();
  Future<T?> get(K key, {T? defaultValue});
  Future<Iterable<T>> getAllValues();
  Stream<BoxEvent> watch(K key);

  // Query operations
  Future<Iterable<T>> getValuesWhere(bool Function(T) condition);
  Future<T?> firstWhereOrNull(bool Function(T item) condition);
  Future<T?> firstWhereContains(
    String query, {
    required String Function(T item) searchableText,
  });
  Future<void> foreachValue(Future<void> Function(K key, T value) action);
  Future<void> foreachKey(Future<void> Function(K key) action);

  // Box management operations
  Future<void> ensureInitialized();
  Future<void> deleteFromDisk();
  Future<void> closeBox();
  Future<void> flushBox();
  Future<void> compactBox();

  // Helper functions
  BoxType _getExistingBox();
  Future<BoxType> _openBox();
  bool get _isOpenInHive;
}

abstract class BaseHivezBox<K, T, B> extends BoxInterface<K, T, B> {
  final LogHandler? _logger;
  final Lock _initLock = Lock();
  final Lock _lock = Lock();
  final Lock _additionalLock = Lock();
  B? _box;

  @override
  bool get isInitialized => _box != null;

  @override
  B get box {
    if (_box == null) {
      throw BoxNotInitializedException(
        "Box not initialized. Call ensureInitialized() first.",
      );
    }
    return _box!;
  }

  BaseHivezBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    LogHandler? logger,
  }) : _logger = logger;

  @override
  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    _debugLog(() => 'Initializing box...');
    await _initLock.synchronized(() async {
      if (isInitialized) return;
      try {
        _box = _isOpenInHive ? _getExistingBox() : await _openBox();
        _debugLog(() => 'Box initialized successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error initializing box: $e\n$st');
        rethrow;
      }
    });
  }

  @protected
  void _debugLog(String Function() messageBuilder) {
    if (_logger != null) {
      _logger('[HivezBox:$name] ${messageBuilder()}');
    } else {
      assert(() {
        print('[HivezBox:$name] ${messageBuilder()}');
        return true;
      }());
    }
  }

  @override
  Future<T?> firstWhereContains(
    String query, {
    required String Function(T item) searchableText,
  }) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return null;

    return firstWhereOrNull(
      (item) => searchableText(item).toLowerCase().contains(lowerQuery),
    );
  }

  @override
  Future<Iterable<T>> getValuesWhere(bool Function(T) condition) async {
    final values = await getAllValues();
    return values.where(condition);
  }

  @override
  Future<T?> getAt(int index) => valueAt(index);

  @override
  Future<bool> moveKey(K oldKey, K newKey) async {
    return _additionalLock.synchronized(() async {
      await ensureInitialized();

      final oldValue = await get(oldKey);
      if (oldValue == null) {
        return false;
      }

      await put(newKey, oldValue);
      await delete(oldKey);

      return true;
    });
  }

  Future<R> _executeWrite<R>(Future<R> Function() action) async {
    await ensureInitialized(); // <-- ensures box is ready
    return _lock.synchronized(action);
  }

  Future<R> _executeRead<R>(Future<R> Function() action) async {
    await ensureInitialized();
    return await action(); // safer if action throws
  }

  @override
  Future<void> foreachKey(Future<void> Function(K key) action,
      {bool Function()? breakCondition}) async {
    await _executeRead(() async {
      final keys = await getAllKeys();
      for (final key in keys) {
        await action(key);
        if (breakCondition != null && breakCondition()) {
          return;
        }
      }
    });
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
}

abstract class AbstractHivezBox<K, T, B extends BoxBase<T>>
    extends BaseHivezBox<K, T, B> {
  @override
  bool get isIsolated => false;

  @override
  bool get isOpen {
    if (_box == null) return false;
    return box.isOpen;
  }

  @override
  String? get path => isInitialized ? box.path : _path;

  AbstractHivezBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<void> deleteFromDisk() async {
    _debugLog(() => 'Deleting box from disk...');
    try {
      if (isOpen) {
        await box.deleteFromDisk();
      } else if (_isOpenInHive) {
        await _getExistingBox().deleteFromDisk();
      } else {
        await Hive.deleteBoxFromDisk(name);
      }
      _box = null;
      _debugLog(() => 'Box deleted successfully.');
    } catch (e, st) {
      _debugLog(() => 'Error deleting box: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> closeBox() async {
    _debugLog(() => 'Closing box...');
    if (isOpen) {
      try {
        await box.close();
        _box = null;
        _debugLog(() => 'Box closed successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error closing box: $e\n$st');
        rethrow;
      }
    } else {
      _debugLog(() => 'Box is not open, skipping close...');
    }
  }

  @override
  Future<void> put(K key, T value) async {
    await _executeWrite(() => box.put(key, value));
  }

  @override
  Future<void> putAll(Map<K, T> entries) async {
    await _executeWrite(() => box.putAll(entries));
  }

  @override
  Future<void> putAt(int index, T value) async {
    await _executeWrite(() => box.putAt(index, value));
  }

  @override
  Future<void> delete(K key) async {
    await _executeWrite(() => box.delete(key));
  }

  @override
  Future<void> deleteAt(int index) async {
    await _executeWrite(() => box.deleteAt(index));
  }

  @override
  Future<void> deleteAll(Iterable<K> keys) async {
    await _executeWrite(() => box.deleteAll(keys));
  }

  @override
  Future<void> clear() async {
    await _executeWrite(() => box.clear());
  }

  @override
  Future<bool> containsKey(K key) async {
    return _executeRead(() => Future.value(box.containsKey(key)));
  }

  @override
  Future<int> get length async {
    return _executeRead(() => Future.value(box.length));
  }

  @override
  Future<Iterable<K>> getAllKeys() async {
    return _executeRead(() => Future.value(box.keys.cast<K>()));
  }

  @override
  Future<int> add(T value) async {
    return _executeWrite(() => box.add(value));
  }

  @override
  Future<void> addAll(Iterable<T> values) async {
    return _executeWrite(() => box.addAll(values));
  }

  @override
  Future<K> keyAt(int index) async {
    return _executeRead(() => Future.value(box.keyAt(index) as K));
  }

  @override
  Future<bool> get isEmpty async {
    return _executeRead(() => Future.value(box.isEmpty));
  }

  @override
  Future<bool> get isNotEmpty async {
    return _executeRead(() => Future.value(box.isNotEmpty));
  }

  @override
  Future<void> flushBox() async {
    await _executeWrite(() async {
      _debugLog(() => 'Flushing box...');
      try {
        await box.flush();
        _debugLog(() => 'Box flushed successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error flushing box: $e\n$st');
        rethrow;
      }
    });
  }

  @override
  Future<void> compactBox() async {
    await _executeWrite(() => box.compact());
  }

  @override
  Stream<BoxEvent> watch(K key) {
    return box.watch(key: key);
  }

  @override
  bool get _isOpenInHive => Hive.isBoxOpen(name);
}

abstract class AbstractHivezIsolatedBox<K, T, B extends IsolatedBoxBase<T>>
    extends BaseHivezBox<K, T, B> {
  @override
  bool get isIsolated => true;

  @override
  bool get isOpen {
    if (_box == null) return false;
    return box.isOpen;
  }

  @override
  String? get path => _path;

  AbstractHivezIsolatedBox(
    super.name, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<void> deleteFromDisk() async {
    _debugLog(() => 'Deleting box from disk...');
    try {
      if (isOpen) {
        await box.deleteFromDisk();
      } else if (_isOpenInHive) {
        await _getExistingBox().deleteFromDisk();
      } else {
        await IsolatedHive.deleteBoxFromDisk(name);
      }
      _box = null;
      _debugLog(() => 'Box deleted successfully.');
    } catch (e, st) {
      _debugLog(() => 'Error deleting box: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> closeBox() async {
    _debugLog(() => 'Closing box...');
    if (isOpen) {
      try {
        await box.close();
        _box = null;
        _debugLog(() => 'Box closed successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error closing box: $e\n$st');
        rethrow;
      }
    } else {
      _debugLog(() => 'Box is not open, skipping close...');
    }
  }

  @override
  Future<void> put(K key, T value) async {
    await _executeWrite(() => box.put(key, value));
  }

  @override
  Future<void> putAll(Map<K, T> entries) async {
    await _executeWrite(() => box.putAll(entries));
  }

  @override
  Future<void> putAt(int index, T value) async {
    await _executeWrite(() => box.putAt(index, value));
  }

  @override
  Future<void> delete(K key) async {
    await _executeWrite(() => box.delete(key));
  }

  @override
  Future<void> deleteAt(int index) async {
    await _executeWrite(() => box.deleteAt(index));
  }

  @override
  Future<void> deleteAll(Iterable<K> keys) async {
    await _executeWrite(() => box.deleteAll(keys));
  }

  @override
  Future<void> clear() async {
    await _executeWrite(() => box.clear());
  }

  @override
  Future<bool> containsKey(K key) async {
    return _executeRead(() => box.containsKey(key));
  }

  @override
  Future<int> get length async {
    return _executeRead(() => box.length);
  }

  @override
  Future<Iterable<K>> getAllKeys() async {
    return _executeRead(
      () async => Future.value((await box.keys).map((key) => key as K)),
    );
  }

  @override
  Future<int> add(T value) async {
    return _executeWrite(() => box.add(value));
  }

  @override
  Future<void> addAll(Iterable<T> values) async {
    return _executeWrite(() => box.addAll(values));
  }

  @override
  Future<K> keyAt(int index) async {
    return _executeRead(() async => (await box.keyAt(index)) as K);
  }

  @override
  Future<bool> get isEmpty async {
    return _executeRead(() => box.isEmpty);
  }

  @override
  Future<bool> get isNotEmpty async {
    return _executeRead(() => box.isNotEmpty);
  }

  @override
  Future<void> flushBox() async {
    await _executeWrite(() async {
      _debugLog(() => 'Flushing box...');
      try {
        await box.flush();
        _debugLog(() => 'Box flushed successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error flushing box: $e\n$st');
        rethrow;
      }
    });
  }

  @override
  Future<void> compactBox() async {
    await _executeWrite(() => box.compact());
  }

  @override
  Stream<BoxEvent> watch(K key) {
    return box.watch(key: key);
  }

  @override
  bool get _isOpenInHive => IsolatedHive.isBoxOpen(name);
}
