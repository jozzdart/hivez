import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

import '../utils/test_setup.dart';

import 'package:hivez/hivez.dart';

void main() {
  late HivezBoxIsolatedLazy<int, int> hivezBox;

  setUpAll(() async {
    await setupIsolatedHiveTest();
  });

  setUp(() async {
    hivezBox = HivezBoxIsolatedLazy<int, int>('isolatedLazyBoxTest');
    await hivezBox.ensureInitialized();
    await hivezBox.clear();
  });

  tearDownAll(() async {
    await IsolatedHive.deleteBoxFromDisk('isolatedLazyBoxTest');
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
    print('keys: ${await hivezBox.getAllKeys()}');
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

  test('putAt updates by index and valueAt reflects change', () async {
    await hivezBox.putAll({1: 10, 2: 20});
    await hivezBox.putAt(0, 15);
    expect(await hivezBox.valueAt(0), 15);
    expect(await hivezBox.get(1), 15);
  });

  test('firstWhereOrNull finds a matching value or returns null', () async {
    await hivezBox.putAll({1: 10, 2: 20, 3: 30});
    final found = await hivezBox.firstWhereOrNull((v) => v > 15);
    expect(found, 20);
    final none = await hivezBox.firstWhereOrNull((v) => v > 100);
    expect(none, isNull);
  });

  test('firstWhereContains performs case-insensitive substring search',
      () async {
    final box = HivezBoxIsolatedLazy<int, String>('isoLazyTextBox');
    await box.ensureInitialized();
    await box.clear();
    await box.putAll({1: 'Hello World', 2: 'hElLo there', 3: 'Goodbye'});

    final match = await box.firstWhereContains(
      'hello',
      searchableText: (s) => s,
    );
    expect(match, anyOf('Hello World', 'hElLo there'));

    final noMatch = await box.firstWhereContains(
      'nomatch',
      searchableText: (s) => s,
    );
    expect(noMatch, isNull);

    await IsolatedHive.deleteBoxFromDisk('isoLazyTextBox');
  });

  test('watch emits BoxEvent on put and delete for a specific key', () async {
    final events = <BoxEvent>[];

    final sub = hivezBox.watch(1).listen(events.add);
    await hivezBox.put(1, 10);
    await hivezBox.put(1, 11);
    await hivezBox.delete(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.first.key, 1);
    expect(events.first.deleted, isFalse);
    expect(events.first.value, anyOf(10, 11));
    expect(events.last.key, 1);
    expect(events.last.deleted, isTrue);
    expect(events.last.value, anyOf(isNull, 11));
  });

  test('flush, close and reopen preserves data', () async {
    await hivezBox.putAll({1: 10, 2: 20});
    await hivezBox.flushBox();
    expect(await hivezBox.length, 2);

    await hivezBox.closeBox();

    await hivezBox.ensureInitialized();
    expect(await hivezBox.get(1), 10);
    expect(await hivezBox.get(2), 20);
  });

  test('compactBox executes without errors', () async {
    await hivezBox.putAll({1: 10, 2: 20, 3: 30});
    await hivezBox.delete(2);
    await hivezBox.compactBox();
    expect(await hivezBox.containsKey(1), true);
    expect(await hivezBox.containsKey(2), false);
  });

  test('deleteFromDisk removes box data from disk', () async {
    final box = HivezBoxIsolatedLazy<int, int>('isoLazyDiskBox');
    await box.ensureInitialized();
    await box.clear();
    await box.putAll({1: 10, 2: 20});
    expect(await box.length, 2);

    await box.deleteFromDisk();

    final box2 = HivezBoxIsolatedLazy<int, int>('isoLazyDiskBox');
    await box2.ensureInitialized();
    expect(await box2.length, 0);
    await box2.deleteFromDisk();
  });

  test('foreachKey visits all keys exactly once and in order', () async {
    await hivezBox.clear();
    final entries = <int, int>{};
    for (var i = 0; i < 160; i++) {
      entries[i] = i * 5;
    }
    await hivezBox.putAll(entries);

    final visitedKeys = <int>[];
    await hivezBox.foreachKey((key) async {
      visitedKeys.add(key);
    });

    final allKeys = (await hivezBox.getAllKeys()).toList();
    expect(visitedKeys, allKeys);
    expect(visitedKeys.toSet(), allKeys.toSet());
  });

  test('foreachValue accumulates sum over many entries', () async {
    await hivezBox.clear();
    final entries = <int, int>{};
    var expectedSum = 0;
    for (var i = 1; i <= 650; i++) {
      entries[i] = i;
      expectedSum += i;
    }
    await hivezBox.putAll(entries);

    var sum = 0;
    await hivezBox.foreachValue((key, value) async {
      sum += value;
    });
    expect(sum, expectedSum);
  });

  test('foreachValue skips null values for nullable isolated lazy box type',
      () async {
    final box = HivezBoxIsolatedLazy<int, String?>('nullableIsoLazyBox');
    await box.ensureInitialized();
    await box.clear();
    await box.putAll({
      1: 'a',
      2: null,
      3: 'c',
      4: null,
      5: 'e',
    });

    final seen = <int, String>{};
    await box.foreachValue((key, value) async {
      seen[key] = value!;
    });

    expect(seen.keys.toSet(), {1, 3, 5});
    expect(seen.values.toSet(), {'a', 'c', 'e'});

    await IsolatedHive.deleteBoxFromDisk('nullableIsoLazyBox');
  });

  test('foreachKey snapshot is stable across mid-iteration mutations',
      () async {
    await hivezBox.clear();
    await hivezBox.putAll({0: 0, 1: 10, 2: 20, 3: 30});

    final visited = <int>[];
    await hivezBox.foreachKey((key) async {
      visited.add(key);
      if (key == 1) {
        await hivezBox.put(999, 999);
      }
    });

    expect(visited, [0, 1, 2, 3]);
    expect(await hivezBox.containsKey(999), isTrue);
  });

  test('foreachKey propagates exceptions from action and stops iteration',
      () async {
    await hivezBox.clear();
    await hivezBox.putAll({0: 0, 1: 10, 2: 20, 3: 30});

    var count = 0;
    Future<void> run() => hivezBox.foreachKey((key) async {
          count++;
          if (key == 2) throw StateError('boom');
        });

    await expectLater(run(), throwsA(isA<StateError>()));
    expect(count, lessThan(4));
    expect(count, greaterThanOrEqualTo(3));
  });

  test('moveKey moves value to new key and removes old key', () async {
    await hivezBox.putAll({1: 10});
    final ok = await hivezBox.moveKey(1, 2);
    expect(ok, isTrue);
    expect(await hivezBox.containsKey(1), isFalse);
    expect(await hivezBox.get(2), 10);
    expect(await hivezBox.length, 1);
  });

  test('moveKey returns false for missing old key', () async {
    await hivezBox.putAll({5: 50});
    final ok = await hivezBox.moveKey(1, 2);
    expect(ok, isFalse);
    expect(await hivezBox.containsKey(5), isTrue);
    expect(await hivezBox.length, 1);
  });

  test('moveKey overwrites value if new key exists', () async {
    await hivezBox.putAll({1: 10, 2: 99});
    final ok = await hivezBox.moveKey(1, 2);
    expect(ok, isTrue);
    expect(await hivezBox.containsKey(1), isFalse);
    expect(await hivezBox.get(2), 10);
    expect(await hivezBox.length, 1);
  });
}
