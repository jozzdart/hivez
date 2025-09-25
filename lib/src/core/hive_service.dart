import 'package:hive_ce/hive.dart';

import 'package:hivez/src/core/base_hive_service.dart';
import 'package:meta/meta.dart';

class HiveService<K, T> extends AbstractHiveService<K, T, Box<T>> {
  HiveService(
    super.boxName, {
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  @protected
  Box<T> getBox() => Hive.box<T>(boxName);

  @override
  @protected
  Future<Box<T>> openBox() async => await Hive.openBox<T>(
        boxName,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
      );
}
