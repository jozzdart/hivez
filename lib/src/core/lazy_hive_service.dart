import 'package:hive_ce/hive.dart';

import 'package:hivez/src/core/base_hive_service.dart';
import 'package:meta/meta.dart';

class LazyHiveService<K, T> extends AbstractHiveService<K, T, LazyBox<T>> {
  LazyHiveService(
    super.boxName, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  @protected
  LazyBox<T> getBox() => Hive.lazyBox<T>(boxName);

  @override
  @protected
  Future<LazyBox<T>> openBox() async => await Hive.openLazyBox<T>(
        boxName,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );
}
