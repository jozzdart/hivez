import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

import '../utils/test_setup.dart';

import 'package:hivez/hivez.dart';

void main() {
  setUpAll(() async {
    await setupHiveTest();
  });

  group('backup_compressed HivezBox', () {
    late HivezBox<String, String> box;

    setUp(() async {
      box = HivezBox<String, String>('backupCompressedBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('backupCompressedBox');
    });

    test('generate and restore compressed snapshot', () async {
      await box.putAll({'a': 'alpha', 'b': 'beta'});
      final data = await box.generateBackupCompressed();

      await box.put('a', 'mut');
      await box.delete('b');

      await box.restoreBackupCompressed(
        data,
        stringToKey: (s) => s,
        jsonToValue: (j) => j as String,
      );

      expect(await box.get('a'), 'alpha');
      expect(await box.get('b'), 'beta');
      expect(await box.length, 2);
    });
  });

  group('backup_compressed HivezLazyBox', () {
    late HivezBoxLazy<String, String> box;

    setUp(() async {
      box = HivezBoxLazy<String, String>('backupCompressedLazyBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('backupCompressedLazyBox');
    });

    test('generate and restore compressed snapshot (lazy)', () async {
      await box.putAll({'x': 'ex', 'y': 'why'});
      final data = await box.generateBackupCompressed();

      await box.put('x', 'mut');
      await box.delete('y');

      await box.restoreBackupCompressed(
        data,
        stringToKey: (s) => s,
        jsonToValue: (j) => j as String,
      );

      expect(await box.get('x'), 'ex');
      expect(await box.get('y'), 'why');
      expect(await box.length, 2);
    });
  });
}
