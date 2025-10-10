import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/src/special_boxes/indexed/indexed.dart';

void main() {
  group('NoopTokenKeyCache', () {
    test('always calls loader; invalidate/clear are no-ops', () async {
      final cache = const NoopTokenKeyCache<int>();

      var calls = 0;
      Future<List<int>> loaderA() async {
        calls++;
        return [1, 2, 3];
      }

      final a1 = await cache.get('a', loaderA);
      final a2 = await cache.get('a', loaderA);
      expect(a1, [1, 2, 3]);
      expect(a2, [1, 2, 3]);
      expect(calls, 2, reason: 'Noop cache should not cache results');

      // invalidate & clear do nothing
      cache.invalidateTokens(['a']);
      cache.clear();

      final a3 = await cache.get('a', loaderA);
      expect(a3, [1, 2, 3]);
      expect(calls, 3);
    });
  });

  group('LruTokenKeyCache', () {
    test('constructor asserts on non-positive capacity', () {
      expect(() => LruTokenKeyCache<int>(0), throwsA(isA<AssertionError>()));
      expect(() => LruTokenKeyCache<int>(-3), throwsA(isA<AssertionError>()));
    });

    test('miss then hit caches and avoids reloading', () async {
      final cache = LruTokenKeyCache<int>(8);

      var calls = 0;
      Future<List<int>> loader() async {
        calls++;
        return [42];
      }

      final first = await cache.get('k', loader);
      final second = await cache.get('k', loader);

      expect(first, [42]);
      expect(second, [42]);
      expect(calls, 1, reason: 'second get should be served from cache');
    });

    test('returned list is unmodifiable', () async {
      final cache = LruTokenKeyCache<int>(4);

      Future<List<int>> loader() async => [1, 2];

      final list = await cache.get('x', loader);
      expect(() => list.add(3), throwsA(isA<UnsupportedError>()));
      expect(() => list.removeAt(0), throwsA(isA<UnsupportedError>()));
    });

    test('evicts least-recently-used when capacity exceeded', () async {
      final cache = LruTokenKeyCache<int>(2);

      var calls = <String, int>{};

      Future<List<int>> loaderFor(String label) async {
        calls[label] = (calls[label] ?? 0) + 1;
        return [label.codeUnitAt(0)]; // arbitrary content
      }

      // Fill to capacity: cache = {a, b}
      await cache.get('a', () => loaderFor('a'));
      await cache.get('b', () => loaderFor('b'));
      expect(calls['a'], 1);
      expect(calls['b'], 1);

      // Access 'a' to make 'b' the LRU: order becomes {b, a} and 'a' is MRU
      await cache.get('a', () => loaderFor('a'));
      expect(calls['a'], 1, reason: 'should be cache hit');

      // Insert 'c', causing eviction of LRU ('b')
      await cache.get('c', () => loaderFor('c'));
      expect(calls['c'], 1);

      // Now, 'b' should be a miss (evicted), 'a' should still be a hit
      await cache.get('a', () => loaderFor('a')); // hit
      await cache.get('b', () => loaderFor('b')); // miss -> reload

      expect(calls['a'], 1, reason: '"a" remained cached');
      expect(calls['b'], 2, reason: '"b" was evicted and reloaded');
    });

    test('refresh on hit prevents that token from being evicted next',
        () async {
      final cache = LruTokenKeyCache<int>(2);

      var calls = <String, int>{};

      Future<List<int>> loaderFor(String label) async {
        calls[label] = (calls[label] ?? 0) + 1;
        return [label.length];
      }

      // Warm: {x, y}
      await cache.get('x', () => loaderFor('x'));
      await cache.get('y', () => loaderFor('y'));
      expect(calls['x'], 1);
      expect(calls['y'], 1);

      // Touch 'x' to make 'y' LRU
      await cache.get('x', () => loaderFor('x'));
      expect(calls['x'], 1, reason: 'hit should not reload');

      // Add 'z' (evicts LRU 'y')
      await cache.get('z', () => loaderFor('z'));
      expect(calls['z'], 1);

      // 'x' should still be cached; 'y' should be evicted
      await cache.get('x', () => loaderFor('x')); // hit
      await cache.get('y', () => loaderFor('y')); // miss -> reload

      expect(calls['x'], 1);
      expect(calls['y'], 2);
    });

    test('invalidateTokens removes selected entries and forces reload',
        () async {
      final cache = LruTokenKeyCache<int>(8);

      var aCalls = 0;
      var bCalls = 0;

      Future<List<int>> loaderA() async {
        aCalls++;
        return [1];
      }

      Future<List<int>> loaderB() async {
        bCalls++;
        return [2];
      }

      // prime cache
      await cache.get('a', loaderA);
      await cache.get('b', loaderB);
      expect(aCalls, 1);
      expect(bCalls, 1);

      // invalidate 'a' only
      cache.invalidateTokens(['a']);

      // 'a' miss, 'b' hit
      await cache.get('a', loaderA);
      await cache.get('b', loaderB);

      expect(aCalls, 2, reason: '"a" should have been reloaded');
      expect(bCalls, 1, reason: '"b" should still be cached');
    });

    test('clear empties entire cache', () async {
      final cache = LruTokenKeyCache<int>(8);

      var calls = 0;
      Future<List<int>> loader() async {
        calls++;
        return [10];
      }

      await cache.get('t1', loader);
      await cache.get('t2', loader);
      expect(calls, 2);

      // hits
      await cache.get('t1', loader);
      await cache.get('t2', loader);
      expect(calls, 2);

      cache.clear();

      // both should reload after clear
      await cache.get('t1', loader);
      await cache.get('t2', loader);
      expect(calls, 4);
    });

    test('caches empty lists and serves them without reloading', () async {
      final cache = LruTokenKeyCache<int>(4);

      var calls = 0;
      Future<List<int>> loaderEmpty() async {
        calls++;
        return <int>[]; // empty result
      }

      final first = await cache.get('none', loaderEmpty);
      final second = await cache.get('none', loaderEmpty);
      expect(first, isEmpty);
      expect(second, isEmpty);
      expect(calls, 1, reason: 'empty lists should still be cached');
    });

    test('concurrent loads for same key may load twice (documented behavior)',
        () async {
      // This documents current behavior: cache does not coalesce concurrent misses.
      final cache = LruTokenKeyCache<int>(4);

      var calls = 0;
      Future<List<int>> loaderSlow() async {
        // stagger a little to let both miss before map is updated
        await Future<void>.delayed(const Duration(milliseconds: 10));
        calls++;
        return [7];
      }

      final results = await Future.wait([
        cache.get('x', loaderSlow),
        cache.get('x', loaderSlow),
      ]);

      // Both calls returned correct data
      expect(results[0], [7]);
      expect(results[1], [7]);
      // And we loaded twice (since we don't deduplicate concurrent loads)
      expect(calls, 2);
    });
  });
}
