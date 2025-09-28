import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

import '../utils/test_setup.dart';

import 'package:hivez/hivez.dart';

void main() {
  late HivezBoxIsolated<int, int> hivezBox;

  setUpAll(() async {
    await setupIsolatedHiveTest();
  });

  setUp(() async {
    hivezBox = HivezBoxIsolated<int, int>('isolatedBoxTest');
    await hivezBox.ensureInitialized();
    await hivezBox.clear();
  });

  tearDownAll(() async {
    await IsolatedHive.deleteBoxFromDisk('isolatedBoxTest');
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
}
