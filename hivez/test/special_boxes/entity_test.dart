import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/hivez.dart';
import 'package:hivez/src/special_boxes/hivez_entity_box.dart';
import 'package:hivez/src/special_boxes/hivez_hash_index_box.dart';

import '../utils/test_setup.dart';

String _hashList(List<String> strings) {
  final combined = strings.join('|');
  final bytes = utf8.encode(combined);
  final digest = md5.convert(bytes);
  return base64.encode(digest.bytes); // shorter than hex
}

final _testWords = [
  'Apple',
  'Banana',
  'Cherry',
  'Date',
  'Elderberry',
  'Fig',
  'Grape',
  'Honeydew',
  'Kiwi',
  'Lemon',
];

void main() {
  late HivezEntityBox<String> database;
  const testItemBoxName = 'test_items';
  const testHashBoxName = 'test_hashes';

  setUpAll(() async {
    await setupHiveTest();
  });

  setUp(() async {
    database = HivezEntityBox<String>(
      dataBox: HivezBox<int, String>(testItemBoxName),
      hashIndexBox: HivezHashIndexBox(HivezBox(testHashBoxName)),
      hashFunction: (item) => _hashList([item]),
      assignIndex: (index, item) => item,
    );
    await database.ensureInitialized();
  });

  tearDown(() async {
    await database.clear();
  });

  group('WordDatabase Tests', () {
    test('Initialization', () async {
      expect(database, isNotNull);
      expect(await database.dataBox.getAllValues(), isEmpty);
    });

    test('Add single word', () async {
      final testWord = 'Watermelon';

      await database.addItem(testWord);
      final words = await database.dataBox.getAllValues();

      expect(words.length, 1);
      expect(words.first, testWord);
    });

    test('Add multiple words', () async {
      await database.addMultipleItems(_testWords);
      final words = await database.dataBox.getAllValues();

      expect(words.length, _testWords.length);
      expect(words, containsAll(_testWords));
    });

    test('Clear database', () async {
      final testWord = 'Watermelon';

      await database.addItem(testWord);
      await database.clear();
      final words = await database.dataBox.getAllValues();
      expect(words, isEmpty);
    });

    test('Contains ID check', () async {
      final testWord = 'Watermelon';

      final id = await database.addItem(testWord);
      final hash = database.hashFunction(testWord);
      final idAtHash = await database.hashIndexBox.hashBox.get(hash);

      expect(idAtHash, id);
    });
  });
}
