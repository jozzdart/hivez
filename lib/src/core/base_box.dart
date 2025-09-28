import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import 'core.dart';

abstract class BaseHivezBox<K, T, B> implements HivezBoxInterface<K, T, B> {
  final String boxName;
  final HiveCipher? encryptionCipher;
  final bool crashRecovery;
  final String? path;
  final String? collection;

  final LogHandler? logger;

  final Lock _lock = Lock();
  final Lock _initLock = Lock();

  B? _box;

  @protected
  B get box {
    if (_box == null) {
      throw HiveServiceInitException(
        "Box '$boxName' not initialized. Call ensureInitialized() first.",
      );
    }
    return _box!;
  }

  @protected
  bool get isOpen {
    if (_box == null) return false;
    if (isIsolated) {
      return (box as IsolatedBoxBase).isOpen;
    } else {
      return (box as BoxBase).isOpen;
    }
  }

  @protected
  bool get isInitialized => _box != null;

  BaseHivezBox(
    this.boxName, {
    this.encryptionCipher,
    this.crashRecovery = true,
    this.path,
    this.collection,
    this.logger,
  }) {
    assert(boxName.isNotEmpty, 'Box name cannot be empty');
  }

  Future<void> _initBox() async {
    if (isInitialized) return;
    _box = _hiveIsBoxOpen(boxName) ? hiveGetBox() : await hiveOpenBox();
  }

  bool _hiveIsBoxOpen(String boxName) {
    if (isIsolated) return IsolatedHive.isBoxOpen(boxName);
    return Hive.isBoxOpen(boxName);
  }

  @override
  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    await _initLock.synchronized(() async {
      if (isInitialized) return;
      await _initBox();
    });
  }

  @protected
  Future<R> synchronizedWrite<R>(Future<R> Function() action) async {
    await ensureInitialized(); // <-- ensures box is ready
    return _lock.synchronized(action);
  }

  @protected
  Future<R> synchronizedRead<R>(Future<R> Function() action) async {
    await ensureInitialized();
    return await action(); // safer if action throws
  }

  @protected
  void debugLog(String message) {
    if (logger != null) {
      logger!('[HiveService:$boxName] $message');
    } else {
      assert(() {
        print('[HiveService:$boxName] $message');
        return true;
      }());
    }
  }

  @override
  Future<void> closeBox() async {
    _box = null;
  }

  @override
  Future<void> deleteFromDisk() async {
    _box = null;
  }

  Future<void> logBoxInfo() async {
    await ensureInitialized();
    final length = await this.length;
    debugLog('[HiveService] Box "$boxName" contains $length items.');
    debugLog(
        'Keys: ${(await getAllKeys()).take(10).toList()}${length > 10 ? '...' : ''}');
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
}
