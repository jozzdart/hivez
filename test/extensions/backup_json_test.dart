import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hivez/hivez.dart';

import '../utils/test_setup.dart';

void main() {
  setUpAll(() async {
    await setupHiveTest();
  });

  group('backup_json HivezBox', () {
    late HivezBox<String, String> box;

    setUp(() async {
      box = HivezBox<String, String>('backupJsonBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('backupJsonBox');
    });

    test('generate and restore JSON snapshot', () async {
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

    test('supports custom serializers', () async {
      final box2 = HivezBox<int, int>('backupJsonBox2');
      await box2.ensureInitialized();
      await box2.clear();
      await box2.putAll({1: 10, 2: 20});

      final json = await box2.generateBackupJson(
        keyToString: (k) => 'k$k',
        valueToJson: (v) => {'v': v},
      );

      // restore into a new box to verify
      final box3 = HivezBox<int, int>('backupJsonBox3');
      await box3.ensureInitialized();
      await box3.clear();
      await box3.restoreBackupJson(
        json,
        stringToKey: (s) => int.parse(s.substring(1)),
        jsonToValue: (j) => (j as Map)['v'] as int,
      );

      expect(await box3.get(1), 10);
      expect(await box3.get(2), 20);

      await Hive.deleteBoxFromDisk('backupJsonBox2');
      await Hive.deleteBoxFromDisk('backupJsonBox3');
    });
  });

  group('backup_json HivezLazyBox', () {
    late HivezBoxLazy<String, String> box;

    setUp(() async {
      box = HivezBoxLazy<String, String>('backupJsonLazyBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('backupJsonLazyBox');
    });

    test('generate and restore JSON snapshot (lazy)', () async {
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
