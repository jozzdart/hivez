// test/special_box/indexed/search_test.dart
import 'package:flutter_test/flutter_test.dart';

import '../../utils/test_setup.dart';
import 'package:hivez/hivez.dart';
import 'package:hivez/src/special_boxes/special_boxes.dart';

/// A tiny counting cache so we can assert loader calls.
class _CountingCache<K> implements TokenKeyCache<K> {
  final Map<String, List<K>> _map = {};
  final Map<String, int> loads = {}; // token -> number of loads
  final int capacity;
  _CountingCache({this.capacity = 32});

  @override
  Future<List<K>> get(String token, Future<List<K>> Function() loader) async {
    final hit = _map.remove(token);
    if (hit != null) {
      _map[token] = hit; // refresh LRU position
      return hit;
    }
    loads[token] = (loads[token] ?? 0) + 1;
    final fresh = List<K>.unmodifiable(await loader());
    _map[token] = fresh;
    if (_map.length > capacity) {
      _map.remove(_map.keys.first); // naive LRU
    }
    return fresh;
  }

  @override
  void invalidateTokens(Iterable<String> tokens) {
    for (final t in tokens) {
      _map.remove(t);
    }
  }

  @override
  void clear() {
    _map.clear();
    loads.clear();
  }
}

void main() {
  setUpAll(() async {
    await setupHiveTest();
  });

  group('IndexSearcher<int,String> with regular boxes', () {
    late HivezBox<int, String> data; // main data box
    late IndexEngine<int, String> engine; // token -> postings
    late BoxConfig dataCfg;

    late IndexSearcher<int, String> searcher;

    Future<void> putManyBoth(Map<int, String> news) async {
      await data.putAll(news);
      await engine.onPutMany(news);
    }

    setUp(() async {
      final ts = DateTime.now().microsecondsSinceEpoch;

      dataCfg = BoxConfig.regular('searcher_data_$ts');
      data = HivezBox<int, String>(dataCfg.name);
      await data.ensureInitialized();
      await data.clear();

      engine = IndexEngine<int, String>(
        'searcher_idx_$ts',
        analyzer: BasicTextAnalyzer<String>((s) => s),
        matchAllTokens: false, // OR
      );
      await engine.ensureInitialized();
      await engine.clear();

      final cache = LruTokenKeyCache<int>(8);

      searcher = IndexSearcher<int, String>(
        engine: engine,
        cache: cache,
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: true,
        ensureReady: () async {},
        getValue: (k) => data.get(k),
        keyComparator: (a, b) => a.compareTo(b),
      );
    });

    tearDown(() async {
      try {
        await engine.deleteFromDisk();
      } catch (_) {}
      try {
        await data.deleteFromDisk();
      } catch (_) {}
    });

    test('empty query → empty results', () async {
      await putManyBoth({1: 'alpha beta'});
      expect(await searcher.keys(''), isEmpty);
      expect(await searcher.values('   '), isEmpty);
    });

    test('single-token OR search (default)', () async {
      await putManyBoth({
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'pi rho',
      });

      expect((await searcher.keys('alpha')).toSet(), {1});
      expect((await searcher.keys('gamma')).toSet(), {2});
      expect((await searcher.keys('beta')).toSet(), {1, 2});

      final vals = await searcher.values('beta');
      expect(vals.toSet(), {'alpha beta', 'beta gamma'});
    });

    test('multi-token OR search (union of postings)', () async {
      await putManyBoth({
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'pi rho',
      });
      final keys = await searcher.keys('alpha gamma');
      expect(keys.toSet(), {1, 2});
    });

    test('AND semantics via an AND-engine', () async {
      final e2 = IndexEngine<int, String>(
        'searcher_and_${DateTime.now().microsecondsSinceEpoch}',
        analyzer: BasicTextAnalyzer<String>((s) => s),
        matchAllTokens: true, // AND
      );
      await e2.ensureInitialized();
      await e2.clear();

      await data.clear();
      await putManyBoth({
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'alpha gamma',
        4: 'alpha beta gamma',
      });

      final andSearcher = IndexSearcher<int, String>(
        engine: e2,
        cache: LruTokenKeyCache<int>(8),
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: true,
        ensureReady: () async {},
        getValue: (k) => data.get(k),
        keyComparator: (a, b) => a.compareTo(b),
      );

      await e2.onPutMany({
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'alpha gamma',
        4: 'alpha beta gamma',
      });

      expect((await andSearcher.keys('alpha beta')).toSet(), {1, 4});
      expect((await andSearcher.keys('beta gamma')).toSet(), {2, 4});

      await e2.deleteFromDisk();
    });

    test('ordering: default ascending by key (Comparable)', () async {
      await putManyBoth({
        7: 'alpha',
        3: 'alpha',
        5: 'alpha',
        11: 'alpha',
      });
      expect(await searcher.keys('alpha'), orderedEquals([3, 5, 7, 11]));
    });

    test('ordering: custom comparator (reverse)', () async {
      final rev = IndexSearcher<int, String>(
        engine: engine,
        cache: LruTokenKeyCache<int>(8),
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: true,
        ensureReady: () async {},
        getValue: (k) => data.get(k),
        keyComparator: (a, b) => -a.compareTo(b),
      );

      await putManyBoth({
        7: 'alpha',
        3: 'alpha',
        5: 'alpha',
        11: 'alpha',
      });

      expect(await rev.keys('alpha'), orderedEquals([11, 7, 5, 3]));
    });

    test('pagination: limit & offset (bounds-safe)', () async {
      // NOTE: use >=2-char token (normalize() drops 1-char tokens)
      await putManyBoth({
        1: 'tok',
        2: 'tok',
        3: 'tok',
        4: 'tok',
        5: 'tok',
      });

      expect(await searcher.keys('tok', limit: 2, offset: 0),
          orderedEquals([1, 2]));
      expect(await searcher.keys('tok', limit: 2, offset: 1),
          orderedEquals([2, 3]));
      expect(await searcher.keys('tok', limit: 3, offset: 3),
          orderedEquals([4, 5]));
      expect(await searcher.keys('tok', limit: 2, offset: 5), isEmpty);
      // negative offset treated as 0 by clamp
      expect(await searcher.keys('tok', limit: 2, offset: -5),
          orderedEquals([1, 2]));
    });

    test('normalization: punctuation/case fold to tokens; tiny tokens dropped',
        () async {
      await putManyBoth({
        10: 'Hello, DART! flutter_search++',
      });
      expect(await searcher.keys('hello'), [10]);
      expect(await searcher.keys('dart'), [10]);
      expect(await searcher.keys('flutter'), [10]);
      expect(await searcher.keys('search'), [10]);

      // 1-char tokens are dropped by normalize()
      expect(await searcher.keys('f ++ , !'), isEmpty);
    });

    test('verification ON filters stale postings from values()', () async {
      await putManyBoth({
        1: 'alpha beta',
        2: 'beta',
      });

      await data.put(1, 'zzz'); // stale vs engine

      final ks = await searcher.keys('alpha');
      expect(ks, contains(1)); // postings say it matches

      final vs = await searcher.values('alpha');
      expect(vs.any((v) => v == 'zzz'), isFalse); // filtered out
    });

    test('verification OFF returns values even if postings are stale',
        () async {
      await putManyBoth({1: 'alpha'});
      await data.put(1, 'zzz'); // stale vs index

      final noVerify = IndexSearcher<int, String>(
        engine: engine,
        cache: LruTokenKeyCache<int>(8),
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: false,
        ensureReady: () async {},
        getValue: (k) => data.get(k),
      );

      final vs = await noVerify.values('alpha');
      expect(vs, contains('zzz')); // not verified
    });

    test('streams: keysStream & valuesStream (ordered, verified)', () async {
      await putManyBoth({
        1: 'alpha',
        2: 'alpha',
        3: 'alpha',
      });

      final ks = <int>[];
      await for (final k in searcher.keysStream('alpha')) {
        ks.add(k);
      }
      expect(ks, orderedEquals([1, 2, 3]));

      final vs = <String>[];
      await for (final v in searcher.valuesStream('alpha')) {
        vs.add(v);
      }
      expect(vs, orderedEquals(['alpha', 'alpha', 'alpha']));
    });

    test('ensureReady is invoked before search', () async {
      var called = false;
      final s = IndexSearcher<int, String>(
        engine: engine,
        cache: LruTokenKeyCache<int>(8),
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: true,
        ensureReady: () async {
          called = true;
        },
        getValue: (k) => data.get(k),
      );

      await putManyBoth({1: 'alpha'});
      await s.keys('alpha');
      expect(called, isTrue);
    });

    test('cache: loader called once per token, invalidation reloads', () async {
      final cc = _CountingCache<int>(capacity: 8);
      final s = IndexSearcher<int, String>(
        engine: engine,
        cache: cc,
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: true,
        ensureReady: () async {},
        getValue: (k) => data.get(k),
      );

      await putManyBoth({
        1: 'alpha',
        2: 'alpha',
        3: 'beta',
      });

      final k1 = await s.keys('alpha');
      expect(k1.toSet(), {1, 2});
      expect(cc.loads['alpha'], 1);

      final k2 = await s.keys('alpha');
      expect(k2.toSet(), {1, 2});
      expect(cc.loads['alpha'], 1);

      await engine.onPut(4, 'alpha'); // mutate postings

      final k3 = await s.keys('alpha');
      expect(k3.toSet(), {1, 2}); // still cached
      expect(cc.loads['alpha'], 1);

      cc.invalidateTokens(['alpha']);
      final k4 = await s.keys('alpha');
      expect(k4.toSet(), {1, 2, 4});
      expect(cc.loads['alpha'], 2);
    });

    test('offset == length yields empty; offset > length empty', () async {
      await putManyBoth({
        1: 'tok',
        2: 'tok',
      });
      expect(await searcher.keys('tok', offset: 2), isEmpty);
      expect(await searcher.keys('tok', offset: 3), isEmpty);
    });

    test('mixed: comparator + pagination', () async {
      // NOTE: use >=2-char token
      await putManyBoth({
        1: 'xx',
        2: 'xx',
        3: 'xx',
        4: 'xx',
        5: 'xx',
        6: 'xx',
      });

      final rev = IndexSearcher<int, String>(
        engine: engine,
        cache: LruTokenKeyCache<int>(8),
        analyzer: BasicTextAnalyzer<String>((s) => s),
        verifyMatches: true,
        ensureReady: () async {},
        getValue: (k) => data.get(k),
        keyComparator: (a, b) => -a.compareTo(b),
      );

      // reversed order: 6,5,4,3,2,1
      expect(await rev.keys('xx', limit: 2, offset: 1), orderedEquals([5, 4]));
      expect(
          await rev.keys('xx', limit: 3, offset: 3), orderedEquals([3, 2, 1]));
    });

    test('explicit: single-char tokens are ignored by normalize()', () async {
      await putManyBoth({
        1: 'a',
        2: 'b',
        3: 'ab',
      });
      // 'a' and 'b' are dropped; only 'ab' is a token
      expect(await searcher.keys('a'), isEmpty);
      expect(await searcher.keys('b'), isEmpty);
      expect(await searcher.keys('ab'), containsAllInOrder([3]));
    });
  });
}
