import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

import 'package:hivez/src/core/base_hive_service.dart';
import 'package:hivez/src/exceptions/service_init.dart';

class HiveService<K, T> extends AbstractHiveService<K, T> {
  Box<T>? _box;

  HiveService(super.boxName, {super.logger});

  @override
  bool get isInitialized => _box != null;

  @override
  bool get isOpen => _box?.isOpen ?? false;

  @protected
  Box<T> get box {
    if (_box == null) {
      throw HiveServiceInitException(
        "Box '$boxName' not initialized. Call ensureInitialized() first.",
      );
    }
    return _box!;
  }

  @override
  Future<void> openBox() async {
    if (isInitialized) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<T>(boxName)
        : await Hive.openBox<T>(boxName);
  }

  @override
  Future<void> closeBox() async {
    if (_box?.isOpen ?? false) {
      await _box!.close();
      _box = null;
    }
  }

  @override
  Future<void> deleteFromDisk() async {
    if (_box?.isOpen ?? false) {
      await _box!.deleteFromDisk();
      _box = null;
    } else if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).deleteFromDisk();
    } else {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }
}
