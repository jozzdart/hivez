import 'package:hive_ce/hive.dart';
import 'package:hivez/src/src.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

abstract class AbstractHiveService<K, T, B extends BoxBase<T>> {
  final String boxName;
  final HiveCipher? encryptionCipher;
  final bool crashRecovery;
  final String? path;
  final String? collection;

  final LogHandler? logger;

  final Lock _lock = Lock();
  final Lock _initLock = Lock();

  @protected
  bool get isInitialized => _box != null;

  @protected
  bool get isOpen => _box?.isOpen ?? false;

  @protected
  B getBox();

  @protected
  Future<B> openBox();

  AbstractHiveService(
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
    _box = Hive.isBoxOpen(boxName) ? getBox() : await openBox();
  }

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

  Future<void> closeBox() async {
    if (isOpen) {
      await _box!.close();
      _box = null;
    }
  }

  Future<void> deleteFromDisk() async {
    if (isOpen) {
      await _box!.deleteFromDisk();
      _box = null;
    } else if (Hive.isBoxOpen(boxName)) {
      await getBox().deleteFromDisk();
    } else {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }
}

typedef LogHandler = void Function(String message);
