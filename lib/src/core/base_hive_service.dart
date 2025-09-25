import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import 'package:hivez/src/exceptions/service_init.dart';

abstract class BaseHiveService<K, T> {
  final String boxName;
  Box<T>? _box;
  final Lock _lock = Lock();
  final Lock _initLock = Lock();
  final LogHandler? logger;

  BaseHiveService(this.boxName, {this.logger});

  bool get isInitialized => _box != null;
  bool get isOpen => _box?.isOpen ?? false;

  @protected
  Future<void> onInit() async {}

  Future<void> _init() async {
    if (isInitialized) return;
    await onInit();
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<T>(boxName)
        : await Hive.openBox<T>(boxName);
  }

  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    await _initLock.synchronized(() async {
      if (isInitialized) return;
      await _init();
    });
  }

  @protected
  Box<T> get box {
    if (_box == null) {
      throw HiveServiceInitException(
        "Box '$boxName' not initialized. Call init() first.",
      );
    }
    return _box!;
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

  Future<void> closeBox() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
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

  Future<void> deleteFromDisk() async {
    if (_box != null) {
      await _box!.deleteFromDisk();
      _box = null;
    } else if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).deleteFromDisk();
    } else {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }
}

typedef LogHandler = void Function(String message);
