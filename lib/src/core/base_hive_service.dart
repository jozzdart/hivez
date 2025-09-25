import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

abstract class AbstractHiveService<K, T> {
  final String boxName;
  final HiveCipher? encryptionCipher;
  final bool crashRecovery;
  final String? path;
  final String? collection;

  final LogHandler? logger;

  final Lock _lock = Lock();
  final Lock _initLock = Lock();

  bool get isInitialized;
  bool get isOpen;

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

  @protected
  Future<void> openBox();

  Future<void> ensureInitialized() async {
    if (isInitialized) return;
    await _initLock.synchronized(() async {
      if (isInitialized) return;
      await openBox();
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

  Future<void> closeBox();

  Future<void> deleteFromDisk();
}

typedef LogHandler = void Function(String message);
