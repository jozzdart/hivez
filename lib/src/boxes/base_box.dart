part of 'boxes.dart';

typedef LogHandler = void Function(String message);

abstract class HivezBoxInterface<K, T, BoxType>
    implements
        HivezBoxFunctions,
        HivezBoxOperationsWrite<K, T>,
        HivezBoxOperationsRead<K, T>,
        HivezBoxOperationsDelete<K, T>,
        HivezBoxOperationsQuery<K, T>,
        HivezBoxInfoGetters,
        HivezBoxIdentityGetters {
  BoxType _getBoxFromHive();
  Future<BoxType> _ceateBoxInHive();
  bool get _boxIsOpenOnHive;
}

abstract class HivezBoxOperationsWrite<K, T> {
  Future<void> put(K key, T value);
  Future<void> putAll(Map<K, T> entries);
  Future<void> putAt(int index, T value);
  Future<int> add(T value);
  Future<void> addAll(Iterable<T> values);
}

abstract class HivezBoxOperationsDelete<K, T> {
  Future<void> delete(K key);
  Future<void> deleteAt(int index);
  Future<void> deleteAll(Iterable<K> keys);
  Future<void> clear();
}

abstract class HivezBoxInfoGetters {
  Future<bool> get isEmpty;
  Future<bool> get isNotEmpty;
  Future<int> get length;
}

abstract class HivezBoxIdentityGetters {
  bool get isOpen;
  bool get isInitialized;
  bool get isIsolated;
  bool get isLazy;
}

abstract class HivezBoxOperationsRead<K, T> {
  Future<K> keyAt(int index);
  Future<T?> valueAt(int index);
  Future<T?> getAt(int index);
  Future<bool> containsKey(K key);
  Future<Iterable<K>> getAllKeys();
  Future<T?> get(K key, {T? defaultValue});
  Future<Iterable<T>> getAllValues();
  Stream<BoxEvent> watch(K key);
}

abstract class HivezBoxOperationsQuery<K, T> {
  Future<Iterable<T>> getValuesWhere(bool Function(T) condition);
  Future<T?> firstWhereOrNull(bool Function(T item) condition);
  Future<T?> firstWhereContains(
    String query, {
    required String Function(T item) searchableText,
  });
}

abstract class HivezBoxFunctions {
  Future<void> ensureInitialized();
  Future<void> deleteFromDisk();
  Future<void> closeBox();
  Future<void> flushBox();
  Future<void> compactBox();
}

abstract class BaseHivezBox<K, T, B> implements HivezBoxInterface<K, T, B> {
  final String name;
  final HiveCipher? encryptionCipher;
  final bool crashRecovery;
  final String? path;
  final String? collection;

  final LogHandler? _logger;
  final Lock _initLock = Lock();
  final Lock _lock = Lock();
  B? _box;

  @override
  bool get isInitialized => _box != null;

  B get hiveBox {
    if (_box == null) {
      throw HivezBoxInitException(
        "Box not initialized. Call ensureInitialized() first.",
      );
    }
    return _box!;
  }

  BaseHivezBox(
    this.name, {
    this.encryptionCipher,
    this.crashRecovery = true,
    this.path,
    this.collection,
    LogHandler? logger,
  }) : _logger = logger {
    assert(name.isNotEmpty, 'Box name cannot be empty');
  }

  @override
  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    _debugLog(() => 'Initializing box...');
    await _initLock.synchronized(() async {
      if (isInitialized) return;
      try {
        _box = _boxIsOpenOnHive ? _getBoxFromHive() : await _ceateBoxInHive();
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

  Future<R> _synchronizedWrite<R>(Future<R> Function() action) async {
    await ensureInitialized(); // <-- ensures box is ready
    return _lock.synchronized(action);
  }

  Future<R> _synchronizedRead<R>(Future<R> Function() action) async {
    await ensureInitialized();
    return await action(); // safer if action throws
  }
}

abstract class AbstractHivezBox<K, T, B extends BoxBase<T>>
    extends BaseHivezBox<K, T, B> {
  @override
  bool get isIsolated => false;

  @override
  bool get isOpen {
    if (_box == null) return false;
    return hiveBox.isOpen;
  }

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
        await hiveBox.deleteFromDisk();
      } else if (_boxIsOpenOnHive) {
        await _getBoxFromHive().deleteFromDisk();
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
        await hiveBox.close();
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
    await _synchronizedWrite(() => hiveBox.put(key, value));
  }

  @override
  Future<void> putAll(Map<K, T> entries) async {
    await _synchronizedWrite(() => hiveBox.putAll(entries));
  }

  @override
  Future<void> putAt(int index, T value) async {
    await _synchronizedWrite(() => hiveBox.putAt(index, value));
  }

  @override
  Future<void> delete(K key) async {
    await _synchronizedWrite(() => hiveBox.delete(key));
  }

  @override
  Future<void> deleteAt(int index) async {
    await _synchronizedWrite(() => hiveBox.deleteAt(index));
  }

  @override
  Future<void> deleteAll(Iterable<K> keys) async {
    await _synchronizedWrite(() => hiveBox.deleteAll(keys));
  }

  @override
  Future<void> clear() async {
    await _synchronizedWrite(() => hiveBox.clear());
  }

  @override
  Future<bool> containsKey(K key) async {
    return _synchronizedRead(() => Future.value(hiveBox.containsKey(key)));
  }

  @override
  Future<int> get length async {
    return _synchronizedRead(() => Future.value(hiveBox.length));
  }

  @override
  Future<Iterable<K>> getAllKeys() async {
    return _synchronizedRead(() => Future.value(hiveBox.keys.cast<K>()));
  }

  @override
  Future<int> add(T value) async {
    return _synchronizedWrite(() => hiveBox.add(value));
  }

  @override
  Future<void> addAll(Iterable<T> values) async {
    return _synchronizedWrite(() => hiveBox.addAll(values));
  }

  @override
  Future<K> keyAt(int index) async {
    return _synchronizedRead(() => Future.value(hiveBox.keyAt(index) as K));
  }

  @override
  Future<bool> get isEmpty async {
    return _synchronizedRead(() => Future.value(hiveBox.isEmpty));
  }

  @override
  Future<bool> get isNotEmpty async {
    return _synchronizedRead(() => Future.value(hiveBox.isNotEmpty));
  }

  @override
  Future<void> flushBox() async {
    await _synchronizedWrite(() async {
      _debugLog(() => 'Flushing box...');
      try {
        await hiveBox.flush();
        _debugLog(() => 'Box flushed successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error flushing box: $e\n$st');
        rethrow;
      }
    });
  }

  @override
  Future<void> compactBox() async {
    await _synchronizedWrite(() => hiveBox.compact());
  }

  @override
  Stream<BoxEvent> watch(K key) {
    return hiveBox.watch(key: key);
  }

  @override
  bool get _boxIsOpenOnHive => Hive.isBoxOpen(name);
}

abstract class AbstractHivezIsolatedBox<K, T, B extends IsolatedBoxBase<T>>
    extends BaseHivezBox<K, T, B> {
  @override
  bool get isIsolated => true;

  @override
  bool get isOpen {
    if (_box == null) return false;
    return hiveBox.isOpen;
  }

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
        await hiveBox.deleteFromDisk();
      } else if (_boxIsOpenOnHive) {
        await _getBoxFromHive().deleteFromDisk();
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
        await hiveBox.close();
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
    await _synchronizedWrite(() => hiveBox.put(key, value));
  }

  @override
  Future<void> putAll(Map<K, T> entries) async {
    await _synchronizedWrite(() => hiveBox.putAll(entries));
  }

  @override
  Future<void> putAt(int index, T value) async {
    await _synchronizedWrite(() => hiveBox.putAt(index, value));
  }

  @override
  Future<void> delete(K key) async {
    await _synchronizedWrite(() => hiveBox.delete(key));
  }

  @override
  Future<void> deleteAt(int index) async {
    await _synchronizedWrite(() => hiveBox.deleteAt(index));
  }

  @override
  Future<void> deleteAll(Iterable<K> keys) async {
    await _synchronizedWrite(() => hiveBox.deleteAll(keys));
  }

  @override
  Future<void> clear() async {
    await _synchronizedWrite(() => hiveBox.clear());
  }

  @override
  Future<bool> containsKey(K key) async {
    return _synchronizedRead(() => hiveBox.containsKey(key));
  }

  @override
  Future<int> get length async {
    return _synchronizedRead(() => hiveBox.length);
  }

  @override
  Future<Iterable<K>> getAllKeys() async {
    return _synchronizedRead(
      () async => Future.value((await hiveBox.keys).map((key) => key as K)),
    );
  }

  @override
  Future<int> add(T value) async {
    return _synchronizedWrite(() => hiveBox.add(value));
  }

  @override
  Future<void> addAll(Iterable<T> values) async {
    return _synchronizedWrite(() => hiveBox.addAll(values));
  }

  @override
  Future<K> keyAt(int index) async {
    return _synchronizedRead(() async => (await hiveBox.keyAt(index)) as K);
  }

  @override
  Future<bool> get isEmpty async {
    return _synchronizedRead(() => hiveBox.isEmpty);
  }

  @override
  Future<bool> get isNotEmpty async {
    return _synchronizedRead(() => hiveBox.isNotEmpty);
  }

  @override
  Future<void> flushBox() async {
    await _synchronizedWrite(() async {
      _debugLog(() => 'Flushing box...');
      try {
        await hiveBox.flush();
        _debugLog(() => 'Box flushed successfully.');
      } catch (e, st) {
        _debugLog(() => 'Error flushing box: $e\n$st');
        rethrow;
      }
    });
  }

  @override
  Future<void> compactBox() async {
    await _synchronizedWrite(() => hiveBox.compact());
  }

  @override
  Stream<BoxEvent> watch(K key) {
    return hiveBox.watch(key: key);
  }

  @override
  bool get _boxIsOpenOnHive => IsolatedHive.isBoxOpen(name);
}

class HivezBoxInitException implements Exception {
  final String message;
  HivezBoxInitException(this.message);

  @override
  String toString() => 'HivezBoxInitException: $message';
}
