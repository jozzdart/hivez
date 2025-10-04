// test/index_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/src/special_boxes/special_boxes.dart';

import '../../utils/test_setup.dart';
import 'package:hivez/hivez.dart';

// NOTE: We test IndexEngine directly, using a simple regular index box.
// Analyzer: BasicTextAnalyzer<String>((s) => s) so tokens come from the string itself.

void main() {
  setUpAll(() async {
    await setupHiveTest();
  });

  group('IndexEngine<int,String> (regular index box)', () {
    late IndexEngine<int, String> engine;
    late BoxConfig idxCfg;

    IndexEngine<int, String> newEngine(String name) {
      final cfg = BoxConfig.regular(name);
      return IndexEngine<int, String>(
        cfg,
        analyzer: BasicTextAnalyzer<String>((s) => s),
        matchAllTokens: false,
      );
    }

    setUp(() async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      idxCfg = BoxConfig.regular('idx_engine_$ts');
      engine = IndexEngine<int, String>(
        idxCfg,
        analyzer: BasicTextAnalyzer<String>((s) => s),
        matchAllTokens: false, // default OR semantics
      );
      await engine.ensureInitialized();
      await engine.clear(); // start clean
    });

    tearDown(() async {
      try {
        await engine.deleteFromDisk();
      } catch (_) {
        // be robust if a test already deleted it
      }
    });

    test('readToken returns empty for missing tokens', () async {
      expect(await engine.readToken('nosuch'), isEmpty);
    });

    test('onPut indexes tokens; search OR returns the key', () async {
      // "hello world" -> tokens: hello, world
      await engine.onPut(1, 'Hello, world!');
      expect(await engine.readToken('hello'), [1]);
      expect(await engine.readToken('world'), [1]);

      // OR search: either token matches
      final orKeys = await engine.searchKeys(['hello', 'x']);
      expect(orKeys.toSet(), {1});
    });

    test('onPut does not duplicate keys on re-put of same value', () async {
      await engine.onPut(3, 'alpha beta');
      await engine.onPut(3, 'alpha beta'); // repeat
      final alpha = await engine.readToken('alpha');
      final beta = await engine.readToken('beta');

      // each should list key 3 exactly once
      expect(alpha, [3]);
      expect(beta, [3]);
    });

    test('onPut with oldValue updates postings (remove old tokens)', () async {
      await engine.onPut(7, 'alpha beta');
      // change value so key leaves "beta", enters "gamma"
      await engine.onPut(7, 'alpha gamma', oldValue: 'alpha beta');

      expect(await engine.readToken('alpha'), contains(7));
      expect(await engine.readToken('gamma'), contains(7));
      expect(await engine.readToken('beta'), isNot(contains(7)));
    });

    test('onDelete removes key from all tokens when oldValue provided',
        () async {
      await engine.onPut(11, 'foo bar baz');
      await engine.onDelete(11, oldValue: 'foo bar baz');

      expect(await engine.readToken('foo'), isNot(contains(11)));
      expect(await engine.readToken('bar'), isNot(contains(11)));
      expect(await engine.readToken('baz'), isNot(contains(11)));
    });

    test('onPutMany applies adds & olds as a batch', () async {
      final news = <int, String>{
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'delta',
      };
      // first write
      await engine.onPutMany(news);

      // now change 1 and 2; 3 unchanged
      final olds = <int, String>{
        1: 'alpha beta',
        2: 'beta gamma',
      };
      final updates = <int, String>{
        1: 'alpha', // remove "beta"
        2: 'gamma theta', // remove "beta", add "theta"
      };
      await engine.onPutMany(updates, olds: olds);

      // Verify effects
      expect(await engine.readToken('beta'), isNot(contains(1)));
      expect(await engine.readToken('beta'), isNot(contains(2)));
      expect(await engine.readToken('alpha'), contains(1));
      expect(await engine.readToken('gamma'), contains(2));
      expect(await engine.readToken('theta'), contains(2));
      expect(await engine.readToken('delta'), contains(3));
    });

    test('onDeleteMany removes keys across their tokens (batch)', () async {
      await engine.onPutMany({
        10: 'one two three',
        20: 'two three four',
        30: 'three four five',
      });

      await engine.onDeleteMany({
        10: 'one two three',
        30: 'three four five',
      });

      // 10 & 30 removed; 20 remains
      expect(await engine.readToken('one'), isEmpty);
      expect(await engine.readToken('five'), isEmpty);
      final three = await engine.readToken('three');
      expect(three, contains(20));
      expect(three, isNot(contains(10)));
      expect(three, isNot(contains(30)));
    });

    test('searchKeys OR semantics (default)', () async {
      // 1: "alpha beta", 2: "beta gamma", 3: "pi rho"
      await engine.onPutMany({
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'pi rho',
      });

      // OR of alpha/gamma -> keys {1,2}
      final keys = await engine.searchKeys(['alpha', 'gamma']);
      expect(keys.toSet(), {1, 2});
    });

    test('searchKeys AND semantics', () async {
      final e2 =
          newEngine('idx_engine_and_${DateTime.now().microsecondsSinceEpoch}');
      await e2.ensureInitialized();
      await e2.clear();

      // AND engine
      final andEngine = IndexEngine<int, String>(
        e2.config,
        analyzer: BasicTextAnalyzer<String>((s) => s),
        matchAllTokens: true, // AND
      );
      await andEngine.ensureInitialized();
      await andEngine.clear();

      await andEngine.onPutMany({
        1: 'alpha beta',
        2: 'beta gamma',
        3: 'alpha gamma',
        4: 'alpha beta gamma',
      });

      // AND of alpha & beta -> {1,4}
      final k1 = await andEngine.searchKeys(['alpha', 'beta']);
      expect(k1.toSet(), {1, 4});

      // AND of beta & gamma -> {2,4}
      final k2 = await andEngine.searchKeys(['beta', 'gamma']);
      expect(k2.toSet(), {2, 4});

      // cleanup
      await andEngine.deleteFromDisk();
    });

    test('normalization: punctuation & case folded to ascii word tokens',
        () async {
      await engine.onPut(5, 'Hello, DART! flutter_search++');
      expect(await engine.readToken('hello'), contains(5));
      expect(await engine.readToken('dart'), contains(5));
      expect(await engine.readToken('flutter'), contains(5));
      expect(await engine.readToken('search'), contains(5));
      // tiny tokens (<2 chars) are dropped by normalize()
      expect(await engine.readToken('f'), isEmpty);
      expect(await engine.readToken('++'), isEmpty);
    });

    test('clear wipes the entire index', () async {
      await engine.onPutMany({
        1: 'ab bc cd',
        2: 'bc cd de',
      });
      expect(await engine.readToken('bc'), isNotEmpty);

      await engine.clear();
      expect(await engine.readToken('ab'), isEmpty);
      expect(await engine.readToken('bc'), isEmpty);
      expect(await engine.readToken('cd'), isEmpty);
      expect(await engine.readToken('de'), isEmpty);
    });

    test(
        'onPutMany keeps keys for tokens present in both olds and news (overlap)',
        () async {
      await engine.onPutMany({1: 'alpha beta'});

      final olds = {1: 'alpha beta'};
      final news = {1: 'alpha'}; // alpha stays, beta removed

      await engine.onPutMany(news, olds: olds);

      expect(await engine.readToken('alpha'), contains(1)); // must stay
      expect(await engine.readToken('beta'),
          isNot(contains(1))); // must be removed
    });

    test('flush/compact/close & reopen keep postings intact', () async {
      await engine.onPutMany({
        1: 'alpha beta',
        2: 'beta gamma',
      });

      await engine.flushBox();
      await engine.compactBox();

      await engine.closeBox();
      await engine.ensureInitialized();

      expect(await engine.readToken('alpha'), contains(1));
      expect(await engine.readToken('beta'), containsAll([1, 2]));
      expect(await engine.readToken('gamma'), contains(2));
    });

    test('deleteFromDisk removes index storage; recreate is empty', () async {
      await engine.onPut(42, 'foo bar');
      expect(await engine.readToken('foo'), contains(42));

      await engine.deleteFromDisk();

      // Recreate on the same name
      final e2 = IndexEngine<int, String>(
        idxCfg,
        analyzer: BasicTextAnalyzer<String>((s) => s),
      );
      await e2.ensureInitialized();
      expect(await e2.readToken('foo'), isEmpty);

      await e2.deleteFromDisk();
    });

    test('large batched onPutMany hits internal applyMutations batching',
        () async {
      // Build 2000 keys spread across ~5 tokens
      final news = <int, String>{};
      const tokens = ['alpha', 'beta', 'gamma', 'delta', 'omega'];
      for (var i = 0; i < 2000; i++) {
        // each value contains 2 tokens; overlaps across items
        final t1 = tokens[i % tokens.length];
        final t2 = tokens[(i + 2) % tokens.length];
        news[i] = '$t1 $t2';
      }

      await engine.onPutMany(news);

      // Each token should have many keys
      for (final t in tokens) {
        final ks = await engine.readToken(t);
        expect(ks.length, greaterThan(500),
            reason: 'token $t should be popular');
      }

      // Now delete half of them in a big batch and verify reductions
      final dels = <int, String>{};
      for (var i = 0; i < 2000; i += 2) {
        dels[i] = news[i]!;
      }
      await engine.onDeleteMany(dels);

      for (final t in tokens) {
        final ks = await engine.readToken(t);
        // Still non-empty, but roughly halved
        expect(ks.length, inInclusiveRange(300, 1100));
      }
    });
  });
}
