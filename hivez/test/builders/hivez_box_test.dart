import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart' show BoxEvent;

import '../utils/test_setup.dart';

import 'package:hivez/hivez.dart';

void main() {
  late BoxInterface<int, int> hivezBox;

  setUpAll(() async {
    await setupHiveTest();
  });

  setUp(() async {
    hivezBox = Box.regular('boxTest');
    await hivezBox.ensureInitialized();
    await hivezBox.clear();
  });

  tearDownAll(() async {
    await hivezBox.deleteFromDisk();
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

  test('putAt updates by index and valueAt reflects change', () async {
    await hivezBox.putAll({1: 10, 2: 20});
    // index 0 corresponds to key 1
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
    final box = HivezBox<int, String>('textBox');
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

    await box.deleteFromDisk();
  });

  test('toMap returns current key/value snapshot', () async {
    final box = Box<int, String>.regular('mapBox');
    await box.ensureInitialized();
    await box.clear();
    await box.putAll({1: 'a', 2: 'b'});
    final map = await box.toMap();
    expect(map, {1: 'a', 2: 'b'});
    await box.deleteFromDisk();
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
    // Some adapters emit the last known value on delete
    expect(events.last.value, anyOf(isNull, 11));
  });

  test('flush, close and reopen preserves data', () async {
    await hivezBox.putAll({1: 10, 2: 20});
    await hivezBox.flushBox();
    expect(await hivezBox.length, 2);

    await hivezBox.closeBox();

    // Reopen and verify
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
    final box = Box<int, int>.regular('diskBox');
    await box.ensureInitialized();
    await box.clear();
    await box.putAll({1: 10, 2: 20});
    expect(await box.length, 2);

    await box.deleteFromDisk();

    // Recreate and verify empty
    final box2 = Box<int, int>.regular('diskBox');
    await box2.ensureInitialized();
    expect(await box2.length, 0);
    await box2.deleteFromDisk();
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

  test('foreachKey visits all keys exactly once and in order', () async {
    await hivezBox.clear();
    final entries = <int, int>{};
    for (var i = 0; i < 100; i++) {
      entries[i] = i * 2;
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
    for (var i = 1; i <= 1000; i++) {
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

  test('foreachValue skips null values for nullable box type', () async {
    final box = Box<int, String?>.regular('nullableBox');
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

    await box.deleteFromDisk();
  });

  test('foreachKey preserves initial order; may include new keys appended',
      () async {
    await hivezBox.clear();
    await hivezBox.putAll({0: 0, 1: 10, 2: 20, 3: 30});

    final visited = <int>[];
    await hivezBox.foreachKey((key) async {
      visited.add(key);
      if (key == 1) {
        // mutate: add a new key; should not be visited in this iteration
        await hivezBox.put(999, 999);
      }
    });
    // Initial keys should remain in order
    expect(visited.take(4).toList(), [0, 1, 2, 3]);
    // Some backends include newly added keys at the end during iteration
    expect(visited.length, anyOf(4, 5));
    if (visited.length == 5) {
      expect(visited.last, 999);
    }
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
    expect(count, greaterThanOrEqualTo(3)); // 0,1,2 visited
  });

  group('getApproxSizeBytes', () {
    test('returns 0 for empty box', () async {
      await hivezBox.clear();
      final size = await hivezBox.estimateSizeBytes();
      expect(size, 0);
    });

    test('counts numeric values roughly proportional to count', () async {
      await hivezBox.clear();
      await hivezBox.putAll({1: 1, 2: 2, 3: 3});
      final sizeSmall = await hivezBox.estimateSizeBytes();

      await hivezBox.putAll({4: 4, 5: 5, 6: 6, 7: 7});
      final sizeLarger = await hivezBox.estimateSizeBytes();

      expect(sizeLarger, greaterThan(sizeSmall));
    });

    test('counts string content length correctly', () async {
      final box = HivezBox<int, String>('sizeBox1');
      await box.ensureInitialized();
      await box.clear();

      await box.putAll({
        1: 'a',
        2: 'abc',
        3: 'abcdefghij', // 10 chars
      });

      final size = await box.estimateSizeBytes();
      // Roughly > sum of utf8 lengths (13 chars * ~1 byte each)
      expect(size, greaterThanOrEqualTo(13));
      expect(size, lessThan(200)); // upper sanity bound

      await box.deleteFromDisk();
    });

    test('handles maps and lists recursively', () async {
      final box = HivezBox<int, dynamic>('complexBox');
      await box.ensureInitialized();
      await box.clear();

      await box.putAll({
        1: {'a': 1, 'b': 2},
        2: [1, 2, 3, 4, 5],
      });

      final size = await box.estimateSizeBytes();
      expect(size, greaterThan(0));
      expect(size, lessThan(1000));
      await box.deleteFromDisk();
    });

    test('returns 0 after clear', () async {
      await hivezBox.clear();
      await hivezBox.putAll({1: 100, 2: 200});
      final before = await hivezBox.estimateSizeBytes();
      expect(before, greaterThan(0));

      await hivezBox.clear();
      final after = await hivezBox.estimateSizeBytes();
      expect(after, 0);
    });

    test('handles nullable values gracefully', () async {
      final box = HivezBox<int, String?>('nullableSizeBox');
      await box.ensureInitialized();
      await box.clear();

      await box.putAll({
        1: null,
        2: 'hello',
      });

      final size = await box.estimateSizeBytes();
      expect(size, greaterThanOrEqualTo(5)); // for "hello"
      await box.deleteFromDisk();
    });
  });
}
