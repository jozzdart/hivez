import 'package:flutter_test/flutter_test.dart';

import 'package:hive_ce_flutter/adapters.dart';

import 'package:hivez/hivez.dart';

import '../../utils/test_setup.dart';

void main() {
  group('Swappability between HivezBox and IndexedBox', () {
    const boxName = 'swapBox';

    late HivezBox<int, String> hBox;
    late IndexedBox<int, String> iBox;

    setUp(() async {
      setupHiveTest();
      if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
      if (await Hive.boxExists('${boxName}__idx')) {
        await Hive.deleteBoxFromDisk('${boxName}__idx');
      }
      if (await Hive.boxExists('${boxName}__idx_meta')) {
        await Hive.deleteBoxFromDisk('${boxName}__idx_meta');
      }
    });

    tearDown(() async {
      if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
      if (await Hive.boxExists('${boxName}__idx')) {
        await Hive.deleteBoxFromDisk('${boxName}__idx');
      }
      if (await Hive.boxExists('${boxName}__idx_meta')) {
        await Hive.deleteBoxFromDisk('${boxName}__idx_meta');
      }
    });

    test('Data written by HivezBox is readable by IndexedBox', () async {
      hBox = HivezBox<int, String>(boxName);

      await hBox.ensureInitialized();
      await hBox.clear();
      await hBox.putAll({1: 'apple', 2: 'banana', 3: 'cherry'});
      await hBox.flushBox();
      await hBox.closeBox();

      print('hBox initialized');

      iBox = IndexedBox<int, String>(
        BoxConfig(boxName),
        searchableText: (s) => s,
      );

      expect(await iBox.length, 3);
      expect(await iBox.get(1), 'apple');
      expect(await iBox.get(2), 'banana');

      print('iBox initialized');

      // Should rebuild automatically and allow searching
      final results = await iBox.search('ban');
      print('results: $results');
      expect(results, contains('banana'));
    });

    test('Data written by IndexedBox is readable by HivezBox', () async {
      iBox = IndexedBox<int, String>(
        BoxConfig(boxName),
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({1: 'hello', 2: 'world'});
      await iBox.flushBox();

      hBox = HivezBox<int, String>(boxName);
      await hBox.ensureInitialized();

      expect(await hBox.length, 2);
      expect(await hBox.get(1), 'hello');
      expect(await hBox.get(2), 'world');
    });

    test('IndexedBox rebuilds automatically after plain box modification',
        () async {
      // First create with IndexedBox
      iBox = IndexedBox<int, String>(
        BoxConfig(boxName),
        searchableText: (s) => s,
      );
      await iBox.ensureInitialized();
      await iBox.clear();
      await iBox.putAll({1: 'dog', 2: 'cat', 3: 'mouse'});
      await iBox.flushBox();
      await iBox.closeBox();

      // Now modify using plain HivezBox (simulate out-of-band edit)
      hBox = HivezBox<int, String>(boxName);
      await hBox.ensureInitialized();
      await hBox.put(4, 'elephant');
      await hBox.delete(1); // remove dog
      await hBox.flushBox();
      await hBox.closeBox();

      // Reopen as IndexedBox; should detect mismatch and rebuild index
      final reopened = IndexedBox<int, String>(
        BoxConfig(boxName),
        searchableText: (s) => s,
      );
      await reopened.ensureInitialized();

      // Must see updated content
      final keys = (await reopened.getAllKeys()).toSet();
      expect(keys, {2, 3, 4});

      // Ensure search works on new data
      final results = await reopened.search('ele');
      expect(results, contains('elephant'));
    });

    test('Swapping multiple times preserves content integrity', () async {
      final box1 = HivezBox<int, String>(boxName);
      await box1.ensureInitialized();
      await box1.clear();
      await box1.putAll({1: 'alpha', 2: 'beta', 3: 'gamma'});
      await box1.flushBox();
      await box1.closeBox();

      final box2 = IndexedBox<int, String>(
        BoxConfig(boxName),
        searchableText: (s) => s,
      );
      await box2.ensureInitialized();
      await box2.put(4, 'delta');
      await box2.flushBox();
      await box2.closeBox();

      final box3 = HivezBox<int, String>(boxName);
      await box3.ensureInitialized();
      expect(await box3.length, 4);
      expect(await box3.get(4), 'delta');

      final box4 = IndexedBox<int, String>(
        BoxConfig(boxName),
        searchableText: (s) => s,
      );
      await box4.ensureInitialized();
      final results = await box4.search('del');
      expect(results, contains('delta'));
    });
  });
}
