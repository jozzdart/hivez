// test/special_box/indexed/indexed_box_benchmark_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import '../../utils/test_setup.dart';
import 'package:hivez/hivez.dart';

const bool kRun100kBenchmarks = false;
const _sizes = <int>[200, 500, 1000, 2500, if (kRun100kBenchmarks) 100000];
const _minWords = 3;
const _maxWords = 10;
const _queriesPerRun = 25;
const _writeBatch = 1000;

void main() {
  setUpAll(() async => await setupIsolatedHiveTest());

  final results = <String, Map<String, int>>{};

  Map<int, String> buildDataset(int size, _DeterministicData gen) {
    final m = <int, String>{};
    for (var i = 0; i < size; i++) {
      m[i] = gen.sentence();
    }
    return m;
  }

  Future<void> populateWithEntries(
      BoxInterface<int, String> box, Map<int, String> entries) async {
    await box.ensureInitialized();
    await box.clear();

    if (entries.length <= _writeBatch) {
      await box.putAll(entries);
      return;
    }
    final it = entries.entries.iterator;
    var batch = <int, String>{};
    while (it.moveNext()) {
      batch[it.current.key] = it.current.value;
      if (batch.length >= _writeBatch) {
        await box.putAll(batch);
        batch = <int, String>{};
      }
    }
    if (batch.isNotEmpty) await box.putAll(batch);
  }

  group('benchmarks (short sentences, int keys)', () {
    for (final size in _sizes) {
      group('size = $size', () {
        late HivezBoxIsolatedLazy<int, String> base;
        late HivezBoxIndexed<int, String> indexed;

        setUp(() async {
          base = HivezBoxIsolatedLazy<int, String>('bench_base_$size');
          await base.ensureInitialized();
          await base.clear();

          final config = BoxConfig.isolatedLazy('bench_idx_$size');
          indexed = HivezBoxIndexed<int, String>(
            config,
            searchableText: (s) => s,
            matchAllTokens: false,
            keyComparator: (a, b) => a.compareTo(b),
            tokenCacheCapacity: 1024,
          );
          await indexed.ensureInitialized();
          await indexed.clear();
        });

        tearDown(() async {
          await base.deleteFromDisk();
          await indexed.deleteFromDisk();
        });

        test('populate (timed)', () async {
          final gen = _DeterministicData(seed: 111);
          final entries = buildDataset(size, gen);

          final tBase = Stopwatch()..start();
          await populateWithEntries(base, entries);
          tBase.stop();

          final tIdx = Stopwatch()..start();
          await populateWithEntries(indexed, entries);
          tIdx.stop();

          results['populate_$size'] = {
            'base_ms': tBase.elapsedMilliseconds,
            'indexed_ms': tIdx.elapsedMilliseconds,
          };

          expect(await base.length, size);
          expect(await indexed.length, size);
        });

        test('single-token search (timed)', () async {
          final gen = _DeterministicData(seed: 222);
          final entries = buildDataset(size, gen);
          await populateWithEntries(base, entries);
          await populateWithEntries(indexed, entries);

          final queries = _makeSingleWordQueries(gen.wordPool, _queriesPerRun);

          final tNaive = Stopwatch()..start();
          for (final q in queries) {
            await _naiveSearchKeys(base, q);
          }
          tNaive.stop();

          final tIdx = Stopwatch()..start();
          for (final q in queries) {
            await indexed.searchKeys(q);
          }
          tIdx.stop();

          results['search_1w_$size'] = {
            'base_ms': tNaive.elapsedMilliseconds,
            'indexed_ms': tIdx.elapsedMilliseconds,
          };
        });

        test('two-token search (timed)', () async {
          final gen = _DeterministicData(seed: 333);
          final entries = buildDataset(size, gen);
          await populateWithEntries(base, entries);
          await populateWithEntries(indexed, entries);
          final twoWordQueries =
              _makeTwoWordQueries(gen.wordPool, _queriesPerRun);

          final tNaive = Stopwatch()..start();
          for (final q in twoWordQueries) {
            await _naiveSearchKeys(base, q, matchAll: false);
          }
          tNaive.stop();

          final tIdx = Stopwatch()..start();
          for (final q in twoWordQueries) {
            await indexed.searchKeys(q);
          }
          tIdx.stop();

          results['search_2w_$size'] = {
            'base_ms': tNaive.elapsedMilliseconds,
            'indexed_ms': tIdx.elapsedMilliseconds,
          };
        });
      });
    }
  });

  tearDownAll(() {
    print('\n───────────────────────────────');
    print('📊 Hivez Indexed Box Benchmarks');
    print('───────────────────────────────\n');

    final header =
        '│ Test Name              │   Base (ms) │ Indexed (ms) │  Speedup │';
    print(header);
    print('│────────────────────────│─────────────│──────────────│──────────│');

    for (final entry in results.entries) {
      final testName = entry.key.padRight(24);
      final base = entry.value['base_ms']!;
      final idx = entry.value['indexed_ms']!;
      final ratio = base == 0 ? '∞' : '${(base / idx).toStringAsFixed(1)}×';
      print(
          '│ $testName │ ${base.toString().padLeft(9)} │ ${idx.toString().padLeft(10)} │ ${ratio.padLeft(8)} │');
    }

    print('└──────────────────────────────────────────────────────────────┘\n');
  });
}

// -----------------------------------------------------------------------------
// Helpers – data gen, naive search, query builders
// -----------------------------------------------------------------------------

class _DeterministicData {
  final Random _rng;
  _DeterministicData({int seed = 42}) : _rng = Random(seed);
  static const List<String> _words = [
    'alpha',
    'beta',
    'gamma',
    'delta',
    'omega',
    'lorem',
    'ipsum',
    'dolor',
    'sit',
    'amet',
    'hello',
    'world',
    'flutter',
    'dart',
    'hive',
    'index',
    'search',
    'fast',
    'safe',
    'clean',
    'smart',
    'simple',
    'secure',
    'async',
    'await',
    'cache',
    'token',
    'query',
    'box',
    'value',
    'key',
    'stream',
    'event',
    'backup',
    'restore',
    'sync',
    'atomic',
    'lock',
    'lazy',
    'compact',
    'crash',
    'recover',
    'encrypt',
    'type',
    'test',
    'bench',
    'data'
  ];

  List<String> get wordPool => _words;

  String sentence() {
    final n = _minWords + _rng.nextInt(_maxWords - _minWords + 1);
    final buf = StringBuffer();
    for (var i = 0; i < n; i++) {
      if (i > 0) buf.write(' ');
      buf.write(_words[_rng.nextInt(_words.length)]);
    }
    return buf.toString();
  }
}

Future<List<int>> _naiveSearchKeys(BoxInterface<int, String> box, String query,
    {bool matchAll = false}) async {
  final qTokens = _normalize(query);
  if (qTokens.isEmpty) return const [];

  final out = <int>[];
  await box.foreachValue((k, v) async {
    final tokens = _normalize(v).toSet();
    final ok = matchAll
        ? qTokens.every(tokens.contains)
        : qTokens.any(tokens.contains);
    if (ok) out.add(k);
  });
  out.sort();
  return out;
}

List<String> _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.length > 1)
    .toList();

List<String> _makeSingleWordQueries(List<String> pool, int count) {
  final rng = Random(3);
  return List.generate(count, (_) => pool[rng.nextInt(pool.length)]);
}

List<String> _makeTwoWordQueries(List<String> pool, int count) {
  final rng = Random(5);
  return List.generate(count, (_) {
    final a = pool[rng.nextInt(pool.length)];
    final b = pool[rng.nextInt(pool.length)];
    return '$a $b';
  });
}
