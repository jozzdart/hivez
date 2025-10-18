import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/src/special_boxes/hivez_entity_box.dart';
import 'package:hivez/src/src.dart';

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

  setUpAll(() async {
    await setupHiveTest();
  });

  setUp(() async {
    database = HivezEntityBox<String>(
      IndexedBox<int, String>(testItemBoxName, searchableText: (item) => item),
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
      expect(await database.getAllValues(), isEmpty);
    });

    test('Add single word', () async {
      final testWord = 'Watermelon';

      await database.add(testWord);
      final words = await database.getAllValues();

      expect(words.length, 1);
      expect(words.first, testWord);
    });

    test('Add multiple words', () async {
      await database.addAll(_testWords);
      final words = await database.getAllValues();

      expect(words.length, _testWords.length);
      expect(words, containsAll(_testWords));
    });

    test('Clear database', () async {
      final testWord = 'Watermelon';

      await database.add(testWord);
      await database.clear();
      final words = await database.getAllValues();
      expect(words, isEmpty);
    });

    test('Contains ID check', () async {
      final testWord = 'Watermelon';

      final id = await database.add(testWord);
      final hash = database.hashFunction(testWord);
      final idAtHash = await database.hashIndexBox.get(hash);

      expect(idAtHash, id);
    });
  });
}
