import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hivez/src/boxes/hivez_box.dart';
import 'package:hivez/src/extensions/backup_json.dart';
import 'package:hivez/src/extensions/backup_compressed.dart';

import '../utils/test_setup.dart';

void main() {
  late HivezBox<int, int> hivezBox;

  setUpAll(() async {
    await setupHiveTest();
  });

  setUp(() async {
    hivezBox = HivezBox<int, int>('boxTest');
    await hivezBox.ensureInitialized();
    await hivezBox.clear();
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('boxTest');
  });

  test('put and get value', () async {
    await hivezBox.put(1, 17);
    final result = await hivezBox.get(1);
    expect(result, 17);
  });

  test('get returns default when key missing', () async {
    final result = await hivezBox.get(999, defaultValue: -1);
    expect(result, -1);
  });

  test('putAll and getAllValues', () async {
    await hivezBox.putAll({1: 10, 2: 20, 3: 30});
    final values = await hivezBox.getAllValues();
    expect(values.length, 3);
    expect(values.contains(10), true);
    expect(values.contains(20), true);
    expect(values.contains(30), true);
  });

  test('containsKey, keys, length, isEmpty/isNotEmpty', () async {
    await hivezBox.putAll({1: 10, 2: 20});
    expect(await hivezBox.containsKey(1), true);
    expect(await hivezBox.containsKey(3), false);
    final keys = (await hivezBox.getAllKeys()).toSet();
    expect(keys, {1, 2});
    expect(await hivezBox.length, 2);
    expect(await hivezBox.isEmpty, false);
    expect(await hivezBox.isNotEmpty, true);
  });

  test('delete, deleteAt and deleteAll', () async {
    await hivezBox.putAll({1: 10, 2: 20, 3: 30});
    await hivezBox.delete(2);
    expect(await hivezBox.containsKey(2), false);
    // deleteAt uses index order
    await hivezBox.deleteAt(0);
    final keysAfterDeleteAt = (await hivezBox.getAllKeys()).toSet();
    expect(keysAfterDeleteAt.length, 1);
    await hivezBox.deleteAll(keysAfterDeleteAt);
    expect(await hivezBox.length, 0);
  });

  test('add, addAll, keyAt', () async {
    final k1 = await hivezBox.add(100);
    expect(await hivezBox.get(k1), 100);
    await hivezBox.addAll([200, 300]);
    expect(await hivezBox.length, 3);
    expect(await hivezBox.valueAt(0), 100);
    final firstKey = await hivezBox.keyAt(0);
    expect(await hivezBox.containsKey(firstKey), true);
    await hivezBox.deleteAt(0);
    expect(await hivezBox.length, 2);
  });

  test('clear removes all data', () async {
    await hivezBox.putAll({1: 10, 2: 20});
    await hivezBox.clear();
    expect(await hivezBox.length, 0);
    expect(await hivezBox.isEmpty, true);
  });

  group('String key/value + backup/restore (box)', () {
    late HivezBox<String, String> strBox;

    setUp(() async {
      strBox = HivezBox<String, String>('boxTestStr');
      await strBox.ensureInitialized();
      await strBox.clear();
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('boxTestStr');
    });

    test('put/get with String key and value', () async {
      await strBox.put('k', 'v');
      expect(await strBox.get('k'), 'v');
    });

    test('backup and restore using JSON', () async {
      await strBox.putAll({'a': 'alpha', 'b': 'beta'});
      final json = await strBox.generateBackupJson();

      // mutate data to ensure restore overwrites
      await strBox.put('a', 'zzz');
      await strBox.delete('b');

      await strBox.restoreBackupJson(
        json,
        stringToKey: (s) => s,
        jsonToValue: (j) => j as String,
      );

      expect(await strBox.get('a'), 'alpha');
      expect(await strBox.get('b'), 'beta');
      expect(await strBox.length, 2);
    });

    test('backup and restore using compressed', () async {
      await strBox.putAll({'x': 'ex', 'y': 'why'});
      final data = await strBox.generateBackupCompressed();

      await strBox.put('x', 'mutated');
      await strBox.delete('y');

      await strBox.restoreBackupCompressed(
        data,
        stringToKey: (s) => s,
        jsonToValue: (j) => j as String,
      );

      expect(await strBox.get('x'), 'ex');
      expect(await strBox.get('y'), 'why');
      expect(await strBox.length, 2);
    });
  });
}
