// test/index_journal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/src/special_boxes/special_boxes.dart';

import '../../utils/test_setup.dart';

// If IndexJournal isn't exported publicly, use the internal path you placed it in:

void main() {
  setUpAll(() async {
    await setupHiveTest();
  });

  group('BoxIndexJournal (regular meta box)', () {
    late BoxIndexJournal journal;

    setUp(() async {
      // Use a unique name per test run to avoid collisions in CI
      final ts = DateTime.now().millisecondsSinceEpoch;

      journal = BoxIndexJournal('journal_meta_$ts');
      await journal.ensureInitialized();
      await journal.clear(); // start fresh
    });

    tearDown(() async {
      // Be robust even if a test failed mid-run
      try {
        await journal.deleteFromDisk();
      } catch (_) {}
    });

    test('starts clean by default', () async {
      expect(await journal.isDirty(), isFalse);
    });

    test('runWrite: marks dirty during op, clean after success', () async {
      var dirtyDuring = false;

      await journal.runWrite(() async {
        dirtyDuring = await journal.isDirty(); // must be true inside op
        // do any side writes to the meta box, just to prove it's usable
        await journal.put('payload', 1);
      });

      expect(dirtyDuring, isTrue, reason: 'should be dirty during runWrite');
      expect(await journal.isDirty(), isFalse,
          reason: 'must be clean after successful op');
      expect(await journal.get('payload'), 1,
          reason: 'side writes inside runWrite should persist');
    });

    test('runWrite: stays dirty on exception, survives close/reopen', () async {
      // Ensure clean at start
      expect(await journal.isDirty(), isFalse);

      await expectLater(
        journal.runWrite(() async {
          // become dirty
          expect(await journal.isDirty(), isTrue);
          // simulate partial work
          await journal.put('some_key', 123);
          // crash/failure
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      // Should remain dirty after failure
      expect(await journal.isDirty(), isTrue);

      // Close & reopen should keep the dirty flag
      await journal.closeBox();
      await journal.ensureInitialized();
      expect(await journal.isDirty(), isTrue,
          reason: 'dirty must persist across close/reopen');

      // Recovery (e.g., after rebuild) clears the flag
      await journal.reset();
      expect(await journal.isDirty(), isFalse);
      // Verify that the side write before the crash persisted
      expect(await journal.get('some_key'), 123);
    });

    test('flush/compact/close do not mutate dirty flag', () async {
      // Manually set dirty (equivalent to being mid-op)
      await journal.put('__dirty', 1);
      expect(await journal.isDirty(), isTrue);

      await journal.flushBox();
      expect(await journal.isDirty(), isTrue,
          reason: 'flush must not change dirty state');

      await journal.compactBox();
      expect(await journal.isDirty(), isTrue,
          reason: 'compact must not change dirty state');

      await journal.closeBox();
      await journal.ensureInitialized();
      expect(await journal.isDirty(), isTrue,
          reason: 'close/reopen must preserve dirty state');

      // reset back to clean
      await journal.reset();
      expect(await journal.isDirty(), isFalse);
    });

    test('deleteFromDisk removes journal and recreates clean', () async {
      await journal.put('__dirty', 1);
      expect(await journal.isDirty(), isTrue);

      await journal.deleteFromDisk();

      // Recreate on the same name; should be clean
      final j2 = BoxIndexJournal(journal.name);
      await j2.ensureInitialized();
      expect(await j2.isDirty(), isFalse,
          reason: 'newly created journal should start clean');
      await j2.deleteFromDisk(); // cleanup
    });
  });
}
