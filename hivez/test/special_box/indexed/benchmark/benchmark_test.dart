// ignore: library_annotations
@Timeout(Duration(minutes: 10))
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivez/hivez.dart';

import '../../../utils/test_setup.dart';
import 'words.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Benchmark framework (suite/runner/recorder/printer)
/// ─────────────────────────────────────────────────────────────────────────

/// How many warmup iterations (not recorded)
const int kWarmupIters = 0;

/// How many measured iterations per run
const int kMeasureIters = 1;

/// How many runs per (box × case). Results are averaged.
const int kRunsPerCase = 5;
//const int kRunsPerCase = 20;

/// Global results accumulator: { caseName: { boxName: BenchStats } }
final Map<String, Map<String, BenchStats>> results = {};

const bool kRunMacroBenches = true; // flip to true to run macro benches
const _sizes = <int>[
  100,
  1000,
  5000,
  10000,
  //50000,
];
const _minWords = 3;
const _maxWords = 10;
const _writeBatch = 100000;

/// Order of boxes (for printing columns consistently)
final List<String> boxColumnOrder = [];

/// Simple stats container (per box per case)
class BenchStats {
  final List<int> runMillis; // per run total ms
  BenchStats(this.runMillis);

  int get totalMs => runMillis.fold(0, (a, b) => a + b);
  double get avgMs =>
      (runMillis.isEmpty ? 0 : totalMs / runMillis.length) / 1000;
}

/// A benchmark operation applied per-iteration to a box.
/// You get the iteration index so you can vary keys to avoid overwrites.
typedef BenchOp<K, T> = Future<void> Function(
  BoxInterface<K, T> box,
  int i,
);

/// A “case” describes one thing you want to measure (e.g., put single item).
class BenchCase<K, T> {
  final String name;
  final String description;
  final BenchOp<K, T> op;

  const BenchCase({
    required this.name,
    required this.description,
    required this.op,
  });
}

/// Factory to open/prepare a box to measure, and a cleanup to tear it down.
class BenchBoxFactory<K, T> {
  final String label;
  final Future<BoxInterface<K, T>> Function() open;
  final Future<void> Function() cleanup;

  const BenchBoxFactory({
    required this.label,
    required this.open,
    required this.cleanup,
  });
}

/// A suite bundles cases + box factories, and knows how to run & record them.
class BenchSuite<K, T> {
  final String suiteName;
  final BenchConfig config;
  final List<BenchCase<K, T>> _cases = [];
  final List<BenchBoxFactory<K, T>> _boxes = [];

  BenchSuite(this.suiteName, {this.config = const BenchConfig()});

  void registerCase(BenchCase<K, T> c) => _cases.add(c);

  void registerBox(BenchBoxFactory<K, T> f) {
    _boxes.add(f);
    if (!boxColumnOrder.contains(f.label)) {
      boxColumnOrder.add(f.label);
    }
  }

  Future<void> run() async {
    for (final c in _cases) {
      results.putIfAbsent(c.name, () => <String, BenchStats>{});

      for (final b in _boxes) {
        final runMillis = <int>[];

        BoxInterface<K, T>? shared; // when openOnce=true
        if (config.openOnce) {
          shared = await b.open();
          await shared.ensureInitialized();
          if (config.isolation != BenchIsolation.none) {
            await shared.clear();
          }
        }

        for (int run = 0; run < kRunsPerCase; run++) {
          final box = config.openOnce ? shared! : await b.open();
          if (!config.openOnce) {
            await box.ensureInitialized();
            await box.clear(); // start each run from a known state
          }

          // ── Warmup (unique keys; see Fix 2) ───────────────────────────────
          if (config.doWarmup) {
            final base = run * (kWarmupIters + kMeasureIters);
            for (int i = 0; i < kWarmupIters; i++) {
              await c.op(box, base + i);
            }
            if (config.isolation != BenchIsolation.none) {
              await box.clear();
            }
          }

          // ── Measured (unique keys; see Fix 2) ────────────────────────────
          final base = run * (kWarmupIters + kMeasureIters);
          final sw = Stopwatch()..start();
          for (int i = 0; i < kMeasureIters; i++) {
            await c.op(box, base + kWarmupIters + i);
          }
          sw.stop();
          runMillis.add(sw.elapsedMicroseconds);

          // ── Reset + finalize this run ─────────────────────────────────────
          if (!config.openOnce) {
            await _resetAfterRun(box, config.isolation);
            // Always flush/close when we don't keep the same handle:
            await box.flushBox();
            await box.closeBox();
            await b.cleanup();
          } else {
            if (config.isolation == BenchIsolation.clearBetweenRuns) {
              await box.clear();
            }
          }
        }

        // ── Final cleanup for the shared box ────────────────────────────────
        if (config.openOnce && shared != null) {
          if (config.isolation == BenchIsolation.deleteBetweenRuns) {
            await shared.deleteFromDisk();
          } else {
            await shared.flushBox();
            await shared.closeBox(); // <-- important
          }
          await b.cleanup();
        }

        results[c.name]![b.label] = BenchStats(runMillis);
      }
    }
  }

  Future<void> _resetAfterRun(
    BoxInterface<K, T> box,
    BenchIsolation iso,
  ) async {
    switch (iso) {
      case BenchIsolation.deleteBetweenRuns:
        await box.deleteFromDisk();
        break;
      case BenchIsolation.clearBetweenRuns:
        await box.clear();
        break;
      case BenchIsolation.none:
        // keep data; do nothing
        break;
    }
  }
}

/// Pretty table at the very end (after all benches)
void printResultsTable() {
  if (results.isEmpty) {
    print('\n(no benchmark results)\n');
    return;
  }

  final boxCols = List<String>.from(boxColumnOrder);
  final headerCols =
      <String>['Case'] + boxCols.map((b) => '$b (avg ms)').toList()
        ..add('Best');

  // Column widths
  final colWidths = List<int>.filled(headerCols.length, 0);
  for (int ci = 0; ci < headerCols.length; ci++) {
    colWidths[ci] = headerCols[ci].length;
  }
  void consider(String s, int ci) {
    if (s.length > colWidths[ci]) colWidths[ci] = s.length;
  }

  // Precompute strings and widths

  final rows = <List<String>>[];
  final orderedCases = results.keys.toList()..sort(_caseComparator);

  for (final caseName in orderedCases) {
    final entry = results[caseName]!;
    double? bestMs;
    String? bestBox;

    final msByBox = <String, String>{};
    for (final box in boxCols) {
      final stats = entry[box];
      final avg = stats?.avgMs ?? double.nan;
      final s = stats == null ? '-' : avg.toStringAsFixed(2);
      msByBox[box] = s;

      if (stats != null) {
        if (bestMs == null || avg < bestMs) {
          bestMs = avg;
          bestBox = box;
        }
      }
    }

    final row = <String>[
      caseName,
      ...boxCols.map((b) => msByBox[b]!),
      (bestBox ?? '-'),
    ];

    for (int i = 0; i < row.length; i++) {
      consider(row[i], i);
    }
    rows.add(row);
  }

  String pad(String s, int w) => s.padRight(w);

  // Print
  final sep = '─' * (colWidths.fold<int>(0, (a, b) => a + b + 3) - 1);
  print('\n$sep');
  print('📊 Hivez Benchmarks');
  print(sep);

  // Header
  final header = List.generate(
    headerCols.length,
    (i) => pad(headerCols[i], colWidths[i]),
  ).join(' │ ');
  print(header);
  print(List.generate(headerCols.length, (i) => ''.padRight(colWidths[i], '─'))
      .join('─┼─'));

  // Rows
  for (final row in rows) {
    final line = List.generate(
      row.length,
      (i) => pad(row[i], colWidths[i]),
    ).join(' │ ');
    print(line);
  }

  print('$sep\n');
}

/// ─────────────────────────────────────────────────────────────────────────
/// Demo: ONE benchmark case — “put single item”
/// (Compare HivezBox vs IndexedBox; add more cases later with registerCase)
/// ─────────────────────────────────────────────────────────────────────────
///
int _caseGroup(String name) {
  if (name.startsWith('Put many - n_')) return 0; // first
  if (name.startsWith('Query Search - n_')) return 1; // then searches
  return 2; // everything else
}

void main() {
  setUpAll(() async {
    await setupHiveTest();
  });

  tearDownAll(() {
    // Single place where results are printed:
    printResultsTable();
  });

  group('Macro benchmarks (populate many random items)', () {
    for (final size in _sizes) {
      final sizeStr = (size * kMeasureIters).toString();
      test(
        'populate_putAll_$size (HivezBox vs IndexedBox)',
        () async {
          if (!kRunMacroBenches) {
            // Keep the test green and fast when disabled.
            return;
          }

          final suite = MacroBenchSuite<int, String>(
            'populate_suite_$size',
            config: const BenchConfig(
                openOnce: true, isolation: BenchIsolation.clearBetweenRuns),
          );

          // One block case that does the whole populate in one timed run.
          suite.registerPreparedCase(PreparedBlockBenchCase<int, String>(
            name: 'Put many - n_$sizeStr',
            description: 'putAll random $size items (batched $_writeBatch)',
            preparePerRun: (box) async {
              await box.clear();
              await box.flushBox();
            },
            // TIMED: run just the search
            measured: (box) async {
              final gen = _DeterministicData(seed: 1000 + size);
              final entries = _buildDataset(size, gen);
              await _populateWithEntries(box, entries);
            },
          ));

          suite.registerPreparedCase(PreparedBlockBenchCase<int, String>(
            name: 'Query Search - n_$sizeStr',
            description: 'search inside $size items (search only timed)',
            // NOT TIMED: populate the dataset
            preparePerRun: (box) async {
              final gen = _DeterministicData(seed: 1000 + size);
              final entries = _buildDataset(size, gen);
              await _populateWithEntries(box, entries); // writes happen here
              // If using IndexedBox, its index is built during puts; flush to be safe
              await box.flushBox();
            },
            // TIMED: run just the search
            measured: (box) async {
              const q = 'lo ma';
              if (box is IndexedBox<int, String>) {
                await box.search(q);
              } else {
                await box.search(query: q, searchableText: (s) => s);
              }
            },
          ));

          // HivezBox
          suite.registerBox(BenchBoxFactory<int, String>(
            label: 'HivezBox',
            open: () async {
              final name = 'macro_pop_hivez_${Random().nextInt(1 << 32)}';
              final b = HivezBoxLazy<int, String>(name);
              await b.ensureInitialized();
              await b.clear();
              return b;
            },
            cleanup: () async {},
          ));

          suite.registerBox(BenchBoxFactory<int, String>(
            label: 'IndexedBox',
            open: () async {
              final name =
                  'macro_pop_indexed_default_${Random().nextInt(1 << 32)}';
              final b = IndexedBox<int, String>(
                name,
                type: BoxType.lazy,
                searchableText: (s) => s,
              );
              await b.ensureInitialized();
              await b.clear();
              return b;
            },
            cleanup: () async {},
          ));

          await suite.run();
        },
        // long-ish timeouts only matter if you enable the macro flag
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  });

  group('Benchmark framework', () {
    test('put: single item (keep box + data across runs)', () async {
      // final suite = BenchSuite<int, String>(
      //   'single_put_suite',
      //   config: const BenchConfig(
      //     openOnce: true, // reuse one box
      //     isolation: BenchIsolation.none, // keep data across runs
      //     doWarmup: true,
      //   ),
      // );

      // suite.registerCase(BenchCase<int, String>(
      //   name: 'put_single_item',
      //   description: 'Put a single key/value per iteration',
      //   op: (box, i) async {
      //     // i is already offset per run by the suite → no collisions
      //     await box.put(i, 'v$i');
      //   },
      // ));

      // suite.registerBox(BenchBoxFactory<int, String>(
      //   label: 'IndexedBox BASIC',
      //   open: () async {
      //     final cfg = BoxConfig('bench_put_indexed_keep');
      //     final b = IndexedBox<int, String>(cfg, searchableText: (s) => s);
      //     await b.ensureInitialized();
      //     await b.clear();
      //     return b;
      //   },
      //   cleanup: () async {},
      // ));

      //await suite.run();
      //expect(results.containsKey('put_single_item'), isTrue);
    });
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// Macro (block) benchmark support — for “do a big thing once per run” cases
/// e.g., populate N entries, rebuild, export/import, etc.
/// ─────────────────────────────────────────────────────────────────────────

typedef BlockBenchOp<K, T> = Future<void> Function(BoxInterface<K, T> box);

class BlockBenchCase<K, T> {
  final String name;
  final String description;
  final BlockBenchOp<K, T> runOnce;

  const BlockBenchCase({
    required this.name,
    required this.description,
    required this.runOnce,
  });
}

class MacroBenchSuite<K, T> {
  final String suiteName;
  final BenchConfig config;

  final List<BlockBenchCase<K, T>> _cases = [];
  final List<PreparedBlockBenchCase<K, T>> _preparedCases = [];
  final List<BenchBoxFactory<K, T>> _boxes = [];

  MacroBenchSuite(this.suiteName, {this.config = const BenchConfig()});

  void registerCase(BlockBenchCase<K, T> c) => _cases.add(c);

  void registerPreparedCase(PreparedBlockBenchCase<K, T> c) =>
      _preparedCases.add(c);

  void registerBox(BenchBoxFactory<K, T> f) {
    _boxes.add(f);
    if (!boxColumnOrder.contains(f.label)) {
      boxColumnOrder.add(f.label);
    }
  }

  Future<void> run() async {
    for (final c in _cases) {
      results.putIfAbsent(c.name, () => <String, BenchStats>{});

      for (final b in _boxes) {
        final runMillis = <int>[];

        BoxInterface<K, T>? shared;
        if (config.openOnce) {
          shared = await b.open();
          await shared.ensureInitialized();
          if (config.isolation != BenchIsolation.none) {
            await shared.clear();
          }
        }

        for (int run = 0; run < kRunsPerCase; run++) {
          final box = config.openOnce ? shared! : await b.open();
          if (!config.openOnce) {
            await box.ensureInitialized();
            await box.clear();
          }

          // Optional warmup
          if (config.doWarmup) {
            await c.runOnce(box);
            if (config.isolation != BenchIsolation.none) {
              await box.clear();
            }
          }

          final sw = Stopwatch()..start();
          await c.runOnce(box);
          sw.stop();
          runMillis.add(sw.elapsedMicroseconds);

          if (!config.openOnce) {
            await _resetAfterRun(box, config.isolation);
            await box.flushBox();
            await box.closeBox();
            await b.cleanup();
          } else {
            if (config.isolation == BenchIsolation.clearBetweenRuns) {
              await box.clear();
            }
          }
        }

        if (config.openOnce && shared != null) {
          if (config.isolation == BenchIsolation.deleteBetweenRuns) {
            await shared.deleteFromDisk();
          } else {
            await shared.flushBox();
            await shared.closeBox();
          }
          await b.cleanup();
        }

        results[c.name]![b.label] = BenchStats(runMillis);
      }
    }
    for (final c in _preparedCases) {
      results.putIfAbsent(c.name, () => <String, BenchStats>{});

      for (final b in _boxes) {
        final runMillis = <int>[];

        BoxInterface<K, T>? shared;
        if (config.openOnce) {
          shared = await b.open();
          await shared.ensureInitialized();
          if (config.isolation != BenchIsolation.none) {
            await shared.clear();
          }
        }

        for (int run = 0; run < kRunsPerCase; run++) {
          final box = config.openOnce ? shared! : await b.open();
          if (!config.openOnce) {
            await box.ensureInitialized();
            await box.clear();
          }

          // --- PREPARE (not timed): populate, index, etc. ---
          await c.preparePerRun(box);
          // Make sure on-disk/index state is durable before timing search
          await box.flushBox();

          // Optional warmup: run the measured step once or a few times
          if (config.doWarmup) {
            for (int i = 0; i < kWarmupIters; i++) {
              await c.measured(box);
            }
          }

          // --- MEASURE ONLY THE SEARCH ---
          final sw = Stopwatch()..start();
          for (int i = 0; i < kMeasureIters; i++) {
            await c.measured(box);
          }
          sw.stop();
          runMillis.add(sw.elapsedMicroseconds);

          // Reset between runs
          if (!config.openOnce) {
            await _resetAfterRun(box, config.isolation);
            await box.flushBox();
            await box.closeBox();
            await b.cleanup();
          } else {
            if (config.isolation == BenchIsolation.clearBetweenRuns) {
              await box.clear();
            }
          }
        }

        if (config.openOnce && shared != null) {
          if (config.isolation == BenchIsolation.deleteBetweenRuns) {
            await shared.deleteFromDisk();
          } else {
            await shared.flushBox();
            await shared.closeBox();
          }
          await b.cleanup();
        }

        results[c.name]![b.label] = BenchStats(runMillis);
      }
    }
  }

  Future<void> _resetAfterRun(
    BoxInterface<K, T> box,
    BenchIsolation iso,
  ) async {
    switch (iso) {
      case BenchIsolation.deleteBetweenRuns:
        await box.deleteFromDisk();
        break;
      case BenchIsolation.clearBetweenRuns:
        await box.clear();
        break;
      case BenchIsolation.none:
        break;
    }
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Data helpers (ported)
/// ─────────────────────────────────────────────────────────────────────────

class _DeterministicData {
  final Random _rng;
  _DeterministicData({int seed = 42}) : _rng = Random(seed);

  static const List<String> _words = words;

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

Map<int, String> _buildDataset(int size, _DeterministicData gen) {
  final m = <int, String>{};
  for (var i = 0; i < size; i++) {
    m[i] = gen.sentence();
  }
  return m;
}

Future<void> _populateWithEntries(
  BoxInterface<int, String> box,
  Map<int, String> entries,
) async {
  if (entries.length <= _writeBatch) {
    if (box is IndexedBox<int, String>) {
      await box.replaceAll(entries);
    } else {
      await box.putAll(entries);
    }
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

enum BenchIsolation {
  deleteBetweenRuns, // current behavior
  clearBetweenRuns, // reuse the same box but clear data each run
  none, // keep data; runs accumulate
}

class BenchConfig {
  final bool openOnce; // open one box and reuse for all runs
  final BenchIsolation isolation; // how to reset between runs
  final bool doWarmup; // do warmup loop before measured
  const BenchConfig({
    this.openOnce = false,
    this.isolation = BenchIsolation.deleteBetweenRuns,
    this.doWarmup = true,
  });
}

typedef PreparedBlockPrepare<K, T> = Future<void> Function(
    BoxInterface<K, T> box);
typedef PreparedBlockMeasure<K, T> = Future<void> Function(
    BoxInterface<K, T> box);

class PreparedBlockBenchCase<K, T> {
  final String name;
  final String description;
  final PreparedBlockPrepare<K, T> preparePerRun; // NOT timed
  final PreparedBlockMeasure<K, T> measured; // timed
  const PreparedBlockBenchCase({
    required this.name,
    required this.description,
    required this.preparePerRun,
    required this.measured,
  });
}

int _caseSize(String name) {
  final m = RegExp(r'_(\d+)$').firstMatch(name);
  return m == null ? 1 << 30 : int.parse(m.group(1)!);
}

int _caseComparator(String a, String b) {
  final ga = _caseGroup(a), gb = _caseGroup(b);
  if (ga != gb) return ga - gb; // group order
  final sa = _caseSize(a), sb = _caseSize(b);
  if (sa != sb) return sa - sb; // numeric size ascending
  return a.compareTo(b); // stable fallback
}
