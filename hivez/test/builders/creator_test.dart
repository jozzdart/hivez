import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hivez/hivez.dart';
import 'package:hivez/src/builders/builders.dart';

import '../utils/test_setup.dart';

void main() {
  group('BoxCreator', () {
    setUpAll(() async {
      await setupHiveTest(); // your test helper for Hive
    });

    test('newBox should return HivezBox when type=regular', () {
      final box =
          BoxCreator.newBox<String, int>('regularBox', type: BoxType.regular);
      expect(box, isA<HivezBox<String, int>>());
      expect(box.name, 'regularBox');
      expect(box.type, BoxType.regular);
    });

    test('newBox should return HivezBoxLazy when type=lazy', () {
      final box = BoxCreator.newBox<String, int>('lazyBox', type: BoxType.lazy);
      expect(box, isA<HivezBoxLazy<String, int>>());
      expect(box.type, BoxType.lazy);
    });

    test('newBox should return HivezBoxIsolated when type=isolated', () {
      final box =
          BoxCreator.newBox<String, int>('isolatedBox', type: BoxType.isolated);
      expect(box, isA<HivezBoxIsolated<String, int>>());
      expect(box.type, BoxType.isolated);
    });

    test('newBox should return HivezBoxIsolatedLazy when type=isolatedLazy',
        () {
      final box = BoxCreator.newBox<String, int>('isolatedLazyBox',
          type: BoxType.isolatedLazy);
      expect(box, isA<HivezBoxIsolatedLazy<String, int>>());
      expect(box.type, BoxType.isolatedLazy);
    });

    test('boxFromConfig should produce same type as direct newBox', () {
      const config = BoxConfig('demo', type: BoxType.lazy);
      final fromConfig = BoxCreator.boxFromConfig<String, int>(config);
      final fromNew =
          BoxCreator.newBox<String, int>('demo', type: BoxType.lazy);

      expect(fromConfig.runtimeType, equals(fromNew.runtimeType));
      expect(fromConfig.name, equals(fromNew.name));
      expect(fromConfig.type, BoxType.lazy);
    });

    test('should pass configuration fields properly', () {
      final cipher = HiveAesCipher(List<int>.filled(32, 3));
      void myLogger(String msg) {}
      final config = BoxConfig(
        'secure',
        type: BoxType.regular,
        encryptionCipher: cipher,
        crashRecovery: false,
        path: '/tmp/test',
        collection: 'col',
        logger: myLogger,
      );

      final box = BoxCreator.boxFromConfig<String, int>(config);
      expect(box, isA<HivezBox<String, int>>());
      expect(box.name, 'secure');
      expect(config.encryptionCipher, same(cipher));
      expect(config.logger, same(myLogger));
    });
  });

  group('BoxCreatorImpl', () {
    test('should create HivezBox for BoxType.regular', () {
      final box = BoxCreator.newBox<String, int>('reg', type: BoxType.regular);
      expect(box, isA<HivezBox<String, int>>());
    });

    test('should create HivezBoxLazy for BoxType.lazy', () {
      final box = BoxCreator.newBox<String, int>('lz', type: BoxType.lazy);
      expect(box, isA<HivezBoxLazy<String, int>>());
    });

    test('should create HivezBoxIsolated for BoxType.isolated', () {
      final box = BoxCreator.newBox<String, int>('iso', type: BoxType.isolated);
      expect(box, isA<HivezBoxIsolated<String, int>>());
    });

    test('should create HivezBoxIsolatedLazy for BoxType.isolatedLazy', () {
      final box =
          BoxCreator.newBox<String, int>('isoLz', type: BoxType.isolatedLazy);
      expect(box, isA<HivezBoxIsolatedLazy<String, int>>());
    });
  });

  group('ConfiguredBox', () {
    const config = BoxConfig('configured', type: BoxType.lazy);

    test('should wrap the box from config', () {
      final configured = ConfiguredBox<String, int>(config);
      expect(configured.type, BoxType.lazy);
      expect(configured.config.logger, config.logger);
      expect(configured.config.name, 'configured');
    });
  });
}
