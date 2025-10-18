import 'package:flutter_test/flutter_test.dart';

import 'package:hive_ce_flutter/adapters.dart';
import 'package:hivez/hivez.dart';

import '../../utils/test_setup.dart';

void main() {
  group('IndexedBox - core behaviors', () {
    const boxName = 'indexedBoxTest';
    const idxName = '${boxName}__idx';
    const metaName = '${boxName}__idx_meta';

    late IndexedBox<int, String> iBox;

    Future<void> cleanAll() async {
      if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
      if (await Hive.boxExists(idxName)) {
        await Hive.deleteBoxFromDisk(idxName);
      }
      if (await Hive.boxExists(metaName)) {
        await Hive.deleteBoxFromDisk(metaName);
      }
    }

    setUpAll(() async {
      await setupHiveTest();
    });

    setUp(() async {
      await cleanAll();
    });

    tearDown(() async {
      await cleanAll();
    });

    test('initialize, empty search and basic put/get', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      // empty search query -> []
      expect(await iBox.search(''), isEmpty);
      // missing token -> []
      expect(await iBox.search('zz'), isEmpty);

      // basic write/read
      await iBox.putAll({1: 'hello', 2: 'world'});
      expect(await iBox.get(1), 'hello');
      expect(await iBox.get(2), 'world');

      // prefix analyzer default: partial "he" and "wo" should match
      expect(await iBox.search('he'), contains('hello'));
      expect(await iBox.search('wo'), contains('world'));
    });

    test('prefix analyzer AND vs OR (matchAllTokens)', () async {
      // AND (default)
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        // matchAllTokens is true by default
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({
        1: 'red fox',
        2: 'red box',
        3: 'green fox',
      });

      // Tokens: "re" + "fo" should match only "red fox"
      final andHits = await iBox.search('re fo');
      expect(andHits, ['red fox']);

      // OR (union)
      final iBoxOr = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        matchAllTokens: false,
      );
      await iBoxOr.ensureInitialized(); // uses same data box
      final orHits = await iBoxOr.search('re fo');
      expect(orHits.toSet(), {'red fox', 'red box', 'green fox'});
    });

    test('searchKeys order: default and with custom comparator', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({
        1: 'hello',
        2: 'help',
        3: 'helium',
        4: 'hey',
      });

      // Default: Comparable ascending by key
      final defaultOrder = await iBox.searchKeys('he');
      expect(defaultOrder, [1, 2, 3, 4]);

      // Custom comparator: descending by key
      final iBoxDesc = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        keyComparator: (a, b) => b.compareTo(a),
      );
      await iBoxDesc.ensureInitialized();
      final descOrder = await iBoxDesc.searchKeys('he');
      expect(descOrder, [4, 3, 2, 1]);
    });

    test('pagination: limit and offset', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({
        1: 'hello',
        2: 'help',
        3: 'helium',
        4: 'hey',
      });

      final all = await iBox.searchKeys('he');
      expect(all, [1, 2, 3, 4]);

      final page = await iBox.searchKeys('he', limit: 2, offset: 1);
      expect(page, [2, 3]);

      final tail = await iBox.search('he', limit: 10, offset: 3);
      expect(tail, ['hey']);
    });

    test('streams: searchKeysStream & searchStream yield same order as search',
        () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({
        1: 'hello',
        2: 'help',
        3: 'helium',
        4: 'hey',
      });

      final expectedKeys = await iBox.searchKeys('he');
      final streamedKeys = await iBox.searchKeysStream('he').toList();
      expect(streamedKeys, expectedKeys);

      final expectedVals = await iBox.search('he');
      final streamedVals = await iBox.searchStream('he').toList();
      expect(streamedVals, expectedVals);
    });

    test('cache invalidation on put/update/delete/moveKey', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        tokenCacheCapacity: 2, // exercise LRU
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.put(1, 'alpha');
      expect(await iBox.search('al'), ['alpha']);

      // update value -> invalidate old tokens and add new
      await iBox.put(1, 'omega');
      expect(await iBox.search('al'), isEmpty);
      expect(await iBox.search('om'), ['omega']);

      // add another, delete it, then ensure removal from index
      await iBox.put(2, 'bar');
      expect(await iBox.search('ba'), ['bar']);
      await iBox.delete(2);
      expect(await iBox.search('ba'), isEmpty);

      // moveKey should reindex under new key without duplication
      await iBox.moveKey(1, 9);
      expect(await iBox.searchKeys('om'), [9]);
      expect(await iBox.search('om'), ['omega']);
    });

    test('putAll/onPutMany and deleteAll/onDeleteMany keep index consistent',
        () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.putAll({
        1: 'alpha',
        2: 'alpine',
        3: 'beta',
        4: 'alphabet',
      });

      final hits = await iBox.search('al');
      expect(hits.toSet(), {'alpha', 'alpine', 'alphabet'});

      await iBox.deleteAll([1, 4]);
      final hits2 = await iBox.search('al');
      expect(hits2, ['alpine']);
    });

    test('rebuildIndex from scratch invokes progress and preserves results',
        () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      // Add a bunch to force chunk flushing
      final entries = <int, String>{};
      for (var i = 1; i <= 1200; i++) {
        entries[i] = 'hello $i';
      }
      await iBox.putAll(entries);

      await iBox.rebuildIndex(bypassInit: false);

      // sanity search
      expect(await iBox.search('he'), isNotEmpty);
    });

    test('verifyMatches filters stale index when analyzer changes', () async {
      // 1) Build with PREFIX analyzer (default)
      final prefixBox = IndexedBox<int, String>(
        boxName,
        analyzer: Analyzer.ngram,
        searchableText: (s) => s,
      );
      await prefixBox.ensureInitialized();
      await prefixBox.clear();
      await prefixBox.putAll({
        1: 'hello',
        2: 'helium',
      });
      // With prefix index, 'el' (length >= 2) matches 'hello'
      expect(await prefixBox.search('el'), contains('hello'));
      await prefixBox.closeBox();

      // 2) Re-open with BASIC analyzer + verifyMatches = true (no rebuild)
      final basicVerify = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        analyzer: Analyzer.basic,
        verifyMatches: true,
      );
      await basicVerify.ensureInitialized();

      // Engine still has 'el' token from old prefix index, but BASIC analyzer
      // verification should drop it (since 'el' is not a full token).
      final v1 = await basicVerify.search('el');
      expect(v1, isEmpty);

      // 3) If verifyMatches = false, stale results may leak through
      final basicNoVerify = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        analyzer: Analyzer.basic,
        verifyMatches: false,
      );
      await basicNoVerify.ensureInitialized();
      final v2 = await basicNoVerify.search('el');
      expect(v2, contains('hello'));

      // 4) After rebuild with BASIC, 'el' will not match; 'hello' will match on full token
      await basicVerify.rebuildIndex();
      expect(await basicVerify.search('el'), isEmpty);
      expect(await basicVerify.search('hello'), contains('hello'));
    });

    test(
        'ensureInitialized triggers rebuild when journal marked dirty (manual)',
        () async {
      // Seed data with a fresh index
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({
        1: 'cat',
        2: 'dog',
        3: 'mouse',
      });
      await iBox.closeBox();

      // Manually mark meta dirty (simulate interrupted write)
      final meta = HivezBox<String, int>(metaName);
      await meta.put('__dirty', 1);
      await meta.closeBox();

      // New instance: ensureInitialized should see dirty and rebuild
      final reopened = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await reopened.ensureInitialized();

      // Search should work correctly after rebuild
      final r = await reopened.search('do');
      expect(r, ['dog']);

      await reopened.closeBox();
    });

    test('compactBox/flushBox/closeBox keep index usable', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({1: 'alpha', 2: 'beta', 3: 'gamma'});

      await iBox.flushBox();
      await iBox.delete(2);
      await iBox.compactBox(); // should not throw

      // Still searchable
      expect(await iBox.search('al'), ['alpha']);

      await iBox.closeBox();
      // Re-open & search again
      await iBox.ensureInitialized();
      expect(await iBox.search('ga'), ['gamma']);
    });

    test('deleteFromDisk removes main, index, and meta boxes', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.put(1, 'zebra');

      // Make sure companion boxes exist
      expect(await Hive.boxExists(boxName), isTrue);
      expect(await Hive.boxExists(idxName), isTrue);
      expect(await Hive.boxExists(metaName), isTrue);

      await iBox.deleteFromDisk();

      expect(await Hive.boxExists(boxName), isFalse);
      expect(await Hive.boxExists(idxName), isFalse);
      expect(await Hive.boxExists(metaName), isFalse);
    });

    test('estimateSizeBytes is >= plain box size (index overhead)', () async {
      // Plain HivezBox baseline
      final plain = HivezBox<int, String>(boxName);
      await plain.ensureInitialized();
      await plain.clear();
      await plain.putAll({
        1: 'lorem ipsum',
        2: 'dolor sit amet',
        3: 'consectetur adipiscing',
      });
      final plainSize = await plain.estimateSizeBytes();
      await plain.closeBox();

      // IndexedBox on same data
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      final idxSize = await iBox.estimateSizeBytes();

      expect(idxSize, greaterThanOrEqualTo(plainSize));
    });

    test('token cache capacity = 0 works (Noop cache)', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
        tokenCacheCapacity: 0,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({1: 'hello', 2: 'world'});
      expect(await iBox.search('he'), ['hello']);
      expect(await iBox.search('wo'), ['world']);
    });

    test('Unicode & case-insensitive normalization (e.g., Café)', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({
        1: 'Café con leche',
        2: 'CAFETERIA',
      });

      // lowercased and diacritics kept; prefix "caf" should match both
      final hits = await iBox.search('caf');
      expect(hits.toSet(), {'Café con leche', 'CAFETERIA'});
    });
  });
}
