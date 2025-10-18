import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hivez/hivez.dart';

import '../../utils/test_setup.dart';

void main() {
  group('IndexedBox - searchFiltered & searchPaginated', () {
    const boxName = 'indexedBoxSearchX';
    const idxName = '${boxName}__idx';
    const metaName = '${boxName}__idx_meta';

    late IndexedBox<int, String> iBox;

    Future<void> cleanAll() async {
      if (await Hive.boxExists(boxName)) await Hive.deleteBoxFromDisk(boxName);
      if (await Hive.boxExists(idxName)) await Hive.deleteBoxFromDisk(idxName);
      if (await Hive.boxExists(metaName)) {
        await Hive.deleteBoxFromDisk(metaName);
      }
    }

    setUpAll(() async => await setupHiveTest());
    setUp(() async => await cleanAll());
    tearDown(() async => await cleanAll());

    //---------------------------------------------------------------------------
    // searchFiltered
    //---------------------------------------------------------------------------
    test('searchFiltered applies filter and sort correctly', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.putAll({
        1: 'apple',
        2: 'banana',
        3: 'apricot',
        4: 'avocado',
        5: 'berry',
        6: 'blueberry',
      });

      // ✅ Query "ap" (prefix analyzer needs ≥2 chars)
      final base = await iBox.searchFiltered('ap');
      expect(base.toSet(), {'apple', 'apricot'});

      // ✅ Filtering: only include values containing 'e'
      final filtered = await iBox.searchFiltered(
        'ap',
        filter: (v) => v.contains('e'),
      );
      expect(filtered, ['apple']);

      // ✅ Sorting: reverse alphabetical order
      final sorted = await iBox.searchFiltered(
        'ap',
        sortBy: (a, b) => b.compareTo(a),
      );
      expect(sorted, ['apricot', 'apple']);
    });

    test('searchFiltered limit and offset trims result set', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.putAll({
        1: 'alpha',
        2: 'alphabet',
        3: 'alpine',
        4: 'altitude',
        5: 'almond',
      });

      final all = await iBox.searchFiltered('al');
      expect(all.length, greaterThan(3));

      final limited = await iBox.searchFiltered('al', limit: 2);
      expect(limited.length, 2);

      final offset = await iBox.searchFiltered('al', limit: 2, offset: 2);
      expect(offset.length, 2);
      expect(offset, isA<List<String>>());
    });

    //---------------------------------------------------------------------------
    // searchPaginated
    //---------------------------------------------------------------------------
    test('searchPaginated paginates results correctly (post-filter)', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.putAll({
        1: 'car',
        2: 'cart',
        3: 'carbon',
        4: 'care',
        5: 'carry',
        6: 'cargo',
      });

      final page0 = await iBox.searchPaginated('car', page: 0, pageSize: 2);
      final page1 = await iBox.searchPaginated('car', page: 1, pageSize: 2);
      final page2 = await iBox.searchPaginated('car', page: 2, pageSize: 2);

      expect(page0, isNotEmpty);
      expect(page1, isNotEmpty);
      expect(page2, isNotEmpty);
      expect(page0.any((v) => page1.contains(v)), isFalse);
    });

    test('searchPaginated with prePaginate=true limits early', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.putAll({
        1: 'delta',
        2: 'deluxe',
        3: 'delegate',
        4: 'delivery',
        5: 'delight',
        6: 'delete',
      });

      // ✅ prePaginate limits fetch before filtering
      final prePage = await iBox.searchPaginated(
        'del',
        prePaginate: true,
        page: 0,
        pageSize: 3,
      );
      expect(prePage.length, lessThanOrEqualTo(3));
      expect(prePage.every((v) => v.contains('del')), isTrue);
    });

    test('searchPaginated supports filter and sort correctly', () async {
      iBox = IndexedBox<int, String>(
        boxName,
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();

      await iBox.putAll({
        1: 'red',
        2: 'green',
        3: 'blue',
        4: 'brown',
        5: 'gray',
        6: 'black',
        7: 'blur',
      });

      final res = await iBox.searchPaginated(
        'bl',
        filter: (v) => v.contains('u'),
        sortBy: (a, b) => a.compareTo(b),
        pageSize: 5,
      );

      expect(res, ['blue', 'blur']);
    });

    test('searchPaginated returns empty when page exceeds total', () async {
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

      final res = await iBox.searchPaginated('ca', page: 3, pageSize: 2);
      expect(res, isEmpty);
    });
  });
}
