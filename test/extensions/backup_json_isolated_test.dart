import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hivez/hivez.dart';

import '../utils/test_setup.dart';

void main() {
  setUpAll(() async {
    await setupIsolatedHiveTest();
  });

  group('backup_json HivezIsolatedBox', () {
    late HivezIsolatedBox<String, String> box;

    setUp(() async {
      box = HivezIsolatedBox<String, String>('backupJsonIsolatedBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await IsolatedHive.deleteBoxFromDisk('backupJsonIsolatedBox');
    });

    test('generate and restore JSON snapshot (isolated)', () async {
      await box.putAll({'a': 'alpha', 'b': 'beta'});
      final json = await box.generateBackupJson();

      await box.put('a', 'mut');
      await box.delete('b');

      await box.restoreBackupJson(
        json,
        stringToKey: (s) => s,
        jsonToValue: (j) => j as String,
      );

      expect(await box.get('a'), 'alpha');
      expect(await box.get('b'), 'beta');
      expect(await box.length, 2);
    });
  });

  group('backup_json HivezIsolatedLazyBox', () {
    late HivezIsolatedLazyBox<String, String> box;

    setUp(() async {
      box = HivezIsolatedLazyBox<String, String>('backupJsonIsolatedLazyBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await IsolatedHive.deleteBoxFromDisk('backupJsonIsolatedLazyBox');
    });

    test('generate and restore JSON snapshot (isolated lazy)', () async {
      await box.putAll({'x': 'ex', 'y': 'why'});
      final json = await box.generateBackupJson();

      await box.put('x', 'mut');
      await box.delete('y');

      await box.restoreBackupJson(
        json,
        stringToKey: (s) => s,
        jsonToValue: (j) => j as String,
      );

      expect(await box.get('x'), 'ex');
      expect(await box.get('y'), 'why');
      expect(await box.length, 2);
    });
  });
}
