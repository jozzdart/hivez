import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/hivez.dart';
import 'package:hivez/src/special_boxes/special_boxes.dart';

import '../../utils/test_setup.dart';

// -----------------------------------------------------------------------------
// Config
// -----------------------------------------------------------------------------
const _sizes = [500, 2500, 10000];
const _queries = 10;

void main() {
  setUpAll(() async => await setupHiveTest());

  final results = <String, Map<String, num>>{};

  group('TextAnalyzer Benchmarks', () {
    for (final size in _sizes) {
      test('dataset size $size', () async {
        final gen = _DataGen(seed: 123 + size);
        final entries = _buildDataset(size, gen);
        final queries = _makeQueries(gen.wordPool, _queries);

        // Define analyzers
        final analyzers = <String, TextAnalyzer<String>>{
          'Basic': BasicTextAnalyzer((s) => s),
          'Prefix': PrefixTextAnalyzer((s) => s, minPrefix: 2),
          'NGram': NGramTextAnalyzer((s) => s, minN: 2, maxN: 5),
        };

        for (final entry in analyzers.entries) {
          final label = entry.key;
          final analyzer = entry.value;

          final box = IndexedBox<int, String>(
            'bench_${label}_$size',
            type: BoxType.lazy,
            searchableText: (s) => s,
            overrideAnalyzer: analyzer,
          );

          // Populate and index
          final tBuild = Stopwatch()..start();
          await box.ensureInitialized();
          await box.clear();
          await box.putAll(entries);
          await box.rebuildIndex();
          tBuild.stop();

          // Measure index size
          final totalBytes = await box.estimateSizeBytes();
          await box.closeBox();

          // Search time benchmark
          final tSearch = Stopwatch()..start();
          for (final q in queries) {
            await box.search(q);
          }
          tSearch.stop();

          results['${label}_$size'] = {
            'build_ms': tBuild.elapsedMilliseconds,
            'search_ms': tSearch.elapsedMilliseconds,
            'index_bytes': totalBytes,
          };

          await box.deleteFromDisk();
        }
      });
    }
  });

  tearDownAll(() {
    print('\n───────────────────────────────────────────────');
    print('📊 TextAnalyzer Benchmark Results');
    print('───────────────────────────────────────────────');
    print('│ Analyzer  │ Size │  Build (ms) │ Search (ms) │ Index Size (KB) │');
    print('│────────────│──────│─────────────│─────────────│────────────────│');

    for (final e in results.entries) {
      final parts = e.key.split('_');
      final label = parts[0].padRight(9);
      final size = parts[1].padLeft(4);
      final build = e.value['build_ms']!.toStringAsFixed(0).padLeft(9);
      final search = e.value['search_ms']!.toStringAsFixed(0).padLeft(9);
      final kb =
          (e.value['index_bytes']! / 1024).toStringAsFixed(1).padLeft(12);
      print('│ $label │ $size │ $build │ $search │ $kb │');
    }

    print('└───────────────────────────────────────────────┘\n');
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

Map<int, String> _buildDataset(int size, _DataGen gen) {
  final map = <int, String>{};
  for (int i = 0; i < size; i++) {
    map[i] = gen.sentence();
  }
  return map;
}

List<String> _makeQueries(List<String> pool, int count) {
  final rng = Random(999);
  return List.generate(count, (_) => pool[rng.nextInt(pool.length)]);
}

// -----------------------------------------------------------------------------
// Deterministic text data generator
// -----------------------------------------------------------------------------

class _DataGen {
  final Random _rng;
  _DataGen({int seed = 123}) : _rng = Random(seed);

  static const _words = [
    'alpha',
    'beta',
    'gamma',
    'delta',
    'omega',
    'hello',
    'world',
    'flutter',
    'dart',
    'hive',
    'index',
    'token',
    'query',
    'cache',
    'system',
    'async',
    'await',
    'search',
    'fast',
    'safe',
    'clean',
    'smart',
    'secure',
    'stream',
    'event',
    'data',
    'type',
    'test'
  ];

  List<String> get wordPool => _words;

  String sentence() {
    final n = 3 + _rng.nextInt(6);
    final b = StringBuffer();
    for (int i = 0; i < n; i++) {
      if (i > 0) b.write(' ');
      b.write(_words[_rng.nextInt(_words.length)]);
    }
    return b.toString();
  }
}
