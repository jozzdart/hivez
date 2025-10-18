import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/src/special_boxes/hivez_hash_index_box.dart';

import '../utils/test_setup.dart';

void main() {
  late HivezHashIndexBox hashDatabase;
  const testBoxName = 'test_hash_database';

  setUpAll(() async {
    await setupHiveTest();
  });

  setUp(() async {
    hashDatabase = HivezHashIndexBox(testBoxName);
    await hashDatabase.ensureInitialized();
  });

  tearDown(() async {
    await hashDatabase.clear();
  });

  group('HashDatabase', () {
    test('initialization sets up index correctly', () async {
      final index = await hashDatabase.getCurrentIndex();
      expect(index, equals(1));
    });

    test('getId assigns new IDs for new hashes', () async {
      const hash1 = 'test_hash_1';
      const hash2 = 'test_hash_2';

      final id1 = await hashDatabase.getIndex(hash1);
      final id2 = await hashDatabase.getIndex(hash2);

      expect(id1, equals(1));
      expect(id2, equals(2));
    });

    test('getId returns same ID for same hash', () async {
      const hash = 'test_hash';

      final id1 = await hashDatabase.getIndex(hash);
      final id2 = await hashDatabase.getIndex(hash);

      expect(id1, equals(id2));
    });

    test('getCurrentIndex returns correct index after multiple inserts',
        () async {
      const hash1 = 'test_hash_1';
      const hash2 = 'test_hash_2';

      await hashDatabase.getIndex(hash1);
      await hashDatabase.getIndex(hash2);

      final index = await hashDatabase.getCurrentIndex();
      expect(index, equals(3));
    });

    test('clear resets the database', () async {
      const hash = 'test_hash';
      await hashDatabase.getIndex(hash);

      await hashDatabase.clear();

      final index = await hashDatabase.getCurrentIndex();
      expect(index, equals(1));

      final contains = await hashDatabase.containsHash(hash);
      expect(contains, isFalse);
    });

    test('containsHash returns true for existing hashes', () async {
      const hash = 'test_hash';
      await hashDatabase.getIndex(hash);

      final contains = await hashDatabase.containsHash(hash);
      expect(contains, isTrue);
    });

    test('containsHash returns false for non-existent hashes', () async {
      const hash = 'non_existent_hash';

      final contains = await hashDatabase.containsHash(hash);
      expect(contains, isFalse);
    });

    test('tryGetId returns null for non-existent hashes', () async {
      const hash = 'non_existent_hash';

      final id = await hashDatabase.tryGetIndex(hash);
      expect(id, isNull);
    });

    test('tryGetId returns correct ID for existing hashes', () async {
      const hash = 'test_hash';
      final expectedId = await hashDatabase.getIndex(hash);

      final id = await hashDatabase.tryGetIndex(hash);
      expect(id, equals(expectedId));
    });

    test('generateBackup and restoreBackup work correctly', () async {
      const hash1 = 'test_hash_1';
      const hash2 = 'test_hash_2';

      await hashDatabase.getIndex(hash1);
      await hashDatabase.getIndex(hash2);

      final backup = await hashDatabase.generateBackup();
      await hashDatabase.clear();

      await hashDatabase.restoreBackup(backup);

      final id1 = await hashDatabase.tryGetIndex(hash1);
      final id2 = await hashDatabase.tryGetIndex(hash2);

      expect(id1, equals(1));
      expect(id2, equals(2));
    });

    test('verifyItems removes non-allowed hashes', () async {
      const hash1 = 'test_hash_1';
      const hash2 = 'test_hash_2';
      const hash3 = 'test_hash_3';

      await hashDatabase.getIndex(hash1);
      await hashDatabase.getIndex(hash2);
      await hashDatabase.getIndex(hash3);

      await hashDatabase.verifyHashes([hash1, hash2]);

      final contains1 = await hashDatabase.containsHash(hash1);
      final contains2 = await hashDatabase.containsHash(hash2);
      final contains3 = await hashDatabase.containsHash(hash3);

      expect(contains1, isTrue);
      expect(contains2, isTrue);
      expect(contains3, isFalse);
    });

    test('verifyItems preserves index key', () async {
      const hash1 = 'test_hash_1';
      const hash2 = 'test_hash_2';

      await hashDatabase.getIndex(hash1);
      await hashDatabase.getIndex(hash2);

      await hashDatabase.verifyHashes([hash1]);

      final index = await hashDatabase.getCurrentIndex();
      expect(index, equals(3));
    });

    test('concurrent access to getId is handled correctly', () async {
      const hash1 = 'test_hash_1';
      const hash2 = 'test_hash_2';

      final futures = List.generate(
          10, (index) => hashDatabase.getIndex(index.isEven ? hash1 : hash2));

      final results = await Future.wait(futures);

      final uniqueIds = results.toSet();
      expect(uniqueIds.length, equals(2));
    });
  });
}
