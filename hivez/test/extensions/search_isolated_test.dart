import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hivez/hivez.dart';

import '../utils/test_setup.dart';

void main() {
  setUpAll(() async {
    await setupIsolatedHiveTest();
  });

  group('HivezIsolatedBox search', () {
    late HivezBoxIsolated<int, String> box;

    setUp(() async {
      box = HivezBoxIsolated<int, String>('searchIsolatedBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await IsolatedHive.deleteBoxFromDisk('searchIsolatedBox');
    });

    test('search returns matching items (case-insensitive, multi-term)',
        () async {
      await box.putAll({
        1: 'Alpha beta',
        2: 'Gamma delta',
        3: 'alpha DELTA',
        4: 'zeta',
      });

      final results = await box.search(
        query: 'alpha del',
        searchableText: (s) => s,
      );

      expect(results.length, 1);
      expect(results.first, 'alpha DELTA');
    });

    test('empty query returns all values', () async {
      await box.putAll({1: 'a', 2: 'b', 3: 'c'});
      final results = await box.search(
        query: '',
        searchableText: (s) => s,
      );
      expect(results.length, 3);
      expect(results.toSet(), {'a', 'b', 'c'});
    });

    test('supports sorting and pagination', () async {
      final entries = <int, String>{};
      for (var i = 0; i < 25; i++) {
        entries[i] = 'v${i.toString().padLeft(2, '0')}';
      }
      await box.putAll(entries);

      final page1 = await box.search(
        query: '',
        searchableText: (s) => s,
        sortBy: [SortCriterion<String>((s) => s)],
        page: 1,
        pageSize: 10,
      );

      expect(page1.length, 10);
      expect(page1.first, 'v10');
      expect(page1.last, 'v19');
    });
  });

  group('HivezIsolatedLazyBox search', () {
    late HivezBoxIsolatedLazy<int, String> box;

    setUp(() async {
      box = HivezBoxIsolatedLazy<int, String>('searchIsolatedLazyBox');
      await box.ensureInitialized();
      await box.clear();
    });

    tearDownAll(() async {
      await IsolatedHive.deleteBoxFromDisk('searchIsolatedLazyBox');
    });

    test('search returns matching items (case-insensitive, multi-term)',
        () async {
      await box.putAll({
        1: 'Alpha beta',
        2: 'Gamma delta',
        3: 'alpha DELTA',
        4: 'zeta',
      });

      final results = await box.search(
        query: 'alpha del',
        searchableText: (s) => s,
      );

      expect(results.length, 1);
      expect(results.first, 'alpha DELTA');
    });

    test('empty query returns all values', () async {
      await box.putAll({1: 'a', 2: 'b', 3: 'c'});
      final results = await box.search(
        query: '',
        searchableText: (s) => s,
      );
      expect(results.length, 3);
      expect(results.toSet(), {'a', 'b', 'c'});
    });

    test('supports sorting and pagination', () async {
      final entries = <int, String>{};
      for (var i = 0; i < 25; i++) {
        entries[i] = 'v${i.toString().padLeft(2, '0')}';
      }
      await box.putAll(entries);

      final page1 = await box.search(
        query: '',
        searchableText: (s) => s,
        sortBy: [SortCriterion<String>((s) => s)],
        page: 1,
        pageSize: 10,
      );

      expect(page1.length, 10);
      expect(page1.first, 'v10');
      expect(page1.last, 'v19');
    });
  });
}
