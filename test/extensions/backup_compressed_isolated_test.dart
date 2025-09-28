import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

import '../utils/test_setup.dart';

import 'package:hivez/hivez.dart';

void main() {
  setUpAll(() async {
    await setupIsolatedHiveTest();
  });

  group('backup_compressed HivezIsolatedBox', () {
    late HivezBoxIsolated<String, String> box;

    setUp(() async {
      box = HivezBoxIsolated<String, String>('backupCompressedIsolatedBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await IsolatedHive.deleteBoxFromDisk('backupCompressedIsolatedBox');
    });

    test('generate and restore compressed snapshot (isolated)', () async {
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

  group('backup_compressed HivezIsolatedLazyBox', () {
    late HivezBoxIsolatedLazy<String, String> box;

    setUp(() async {
      box = HivezBoxIsolatedLazy<String, String>(
          'backupCompressedIsolatedLazyBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await IsolatedHive.deleteBoxFromDisk('backupCompressedIsolatedLazyBox');
    });

    test('generate and restore compressed snapshot (isolated lazy)', () async {
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
