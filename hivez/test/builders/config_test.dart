import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hivez/hivez.dart';

import '../utils/test_setup.dart'; // or the correct import path for your library

void main() {
  group('BoxType enum', () {
    test('should have 4 types', () {
      expect(BoxType.values.length, 4);
      expect(BoxType.regular.index, 0);
      expect(BoxType.lazy.index, 1);
      expect(BoxType.isolated.index, 2);
      expect(BoxType.isolatedLazy.index, 3);
    });

    test('should have correct names', () {
      expect(BoxType.regular.name, 'regular');
      expect(BoxType.lazy.name, 'lazy');
      expect(BoxType.isolated.name, 'isolated');
      expect(BoxType.isolatedLazy.name, 'isolatedLazy');
    });
  });

  group('BoxConfig constructors', () {
    test('regular factory should assign correct defaults', () {
      final config = BoxConfig.regular('users');
      expect(config.name, 'users');
      expect(config.type, BoxType.regular);
      expect(config.encryptionCipher, isNull);
      expect(config.crashRecovery, isTrue);
      expect(config.path, isNull);
      expect(config.collection, isNull);
      expect(config.logger, isNull);
    });

    test('lazy factory should assign correct type', () {
      final config = BoxConfig.lazy('cache');
      expect(config.type, BoxType.lazy);
    });

    test('isolated factory should assign correct type', () {
      final config = BoxConfig.isolated('sessions');
      expect(config.type, BoxType.isolated);
    });

    test('isolatedLazy factory should assign correct type', () {
      final config = BoxConfig.isolatedLazy('prefs');
      expect(config.type, BoxType.isolatedLazy);
    });

    test('custom values should be retained', () {
      final cipher = HiveAesCipher(List<int>.filled(32, 1));
      final logHandler = print;
      final config = BoxConfig(
        'secureBox',
        type: BoxType.lazy,
        crashRecovery: false,
        path: '/tmp/hive',
        collection: 'testing',
        logger: logHandler,
        encryptionCipher: cipher,
      );
      expect(config.name, 'secureBox');
      expect(config.type, BoxType.lazy);
      expect(config.crashRecovery, isFalse);
      expect(config.path, '/tmp/hive');
      expect(config.collection, 'testing');
      expect(config.logger, equals(logHandler));
    });
  });

  group('BoxConfig.copyWith()', () {
    test('returns identical object when nothing overridden', () {
      const config = BoxConfig('base', type: BoxType.regular);
      final copy = config.copyWith();
      expect(copy.name, config.name);
      expect(copy.type, config.type);
      expect(copy.path, config.path);
      expect(copy.crashRecovery, config.crashRecovery);
      expect(copy, isNot(same(config)));
    });

    test('should override specific fields', () {
      const base = BoxConfig('base', type: BoxType.regular);
      final updated = base.copyWith(
        name: 'newBase',
        type: BoxType.isolated,
        crashRecovery: false,
        path: '/new/path',
        collection: 'col',
      );

      expect(updated.name, 'newBase');
      expect(updated.type, BoxType.isolated);
      expect(updated.crashRecovery, isFalse);
      expect(updated.path, '/new/path');
      expect(updated.collection, 'col');
    });

    test('does not modify original object', () {
      const base = BoxConfig('original', type: BoxType.lazy);
      final updated = base.copyWith(name: 'changed');
      expect(base.name, 'original');
      expect(updated.name, 'changed');
    });
  });

  group('BoxInterfaceExtensions', () {
    late HivezBox<String, int> box;
    late HivezBoxLazy<String, int> lazy;
    late HivezBoxIsolated<String, int> isolated;
    late HivezBoxIsolatedLazy<String, int> isolatedLazy;

    setUp(() async {
      await setupHiveTest();
      box = HivezBox<String, int>('box');
      lazy = HivezBoxLazy<String, int>('lazy');
      isolated = HivezBoxIsolated<String, int>('isolated');
      isolatedLazy = HivezBoxIsolatedLazy<String, int>('isolatedLazy');
    });

    test('detects correct type for HivezBox', () {
      expect(box.type, BoxType.regular);
    });

    test('detects correct type for HivezBoxLazy', () {
      expect(lazy.type, BoxType.lazy);
    });

    test('detects correct type for HivezBoxIsolated', () {
      expect(isolated.type, BoxType.isolated);
    });

    test('detects correct type for HivezBoxIsolatedLazy', () {
      expect(isolatedLazy.type, BoxType.isolatedLazy);
    });
  });

  group('BoxConfigExtensions', () {
    test('createConfiguredBox returns ConfiguredBox with same config', () {
      const config = BoxConfig('myBox', type: BoxType.regular);
      final configured = config.createConfiguredBox<String, int>();
      expect(configured.config, equals(config));
    });

    test('createBox returns BoxInterface (via BoxCreator)', () {
      const config = BoxConfig('testBox', type: BoxType.regular);
      final box = config.createBox<String, int>();
      expect(box, isA<BoxInterface<String, int>>());
    });
  });
}
