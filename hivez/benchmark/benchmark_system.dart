// benchmark.dart
// Run with: dart run benchmark.dart
// Results are written to: benchmark_results.txt

import 'dart:io';
import 'dart:math';
import 'package:hivez/hivez.dart';
import 'words.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Benchmark constants
/// ─────────────────────────────────────────────────────────────────────────

const int kWarmupIters = 0;
const int kMeasureIters = 1;
const bool kRunMacroBenches = true;

const _minWords = 3;
const _maxWords = 10;
const _writeBatch = 10000000;

final Map<String, Map<String, BenchStats>> results = {};
final List<String> boxColumnOrder = [];

/// ─────────────────────────────────────────────────────────────────────────
/// Core data structures
/// ─────────────────────────────────────────────────────────────────────────

class BenchStats {
  final List<int> runMicros;
  BenchStats(this.runMicros);
  int get total => runMicros.fold(0, (a, b) => a + b);
  double get avgMs => (runMicros.isEmpty ? 0 : total / runMicros.length) / 1000;
}

typedef BenchOp<K, T> = Future<void> Function(BoxInterface<K, T> box, int i);

class BenchCase<K, T> {
  final String name;
  final String description;
  final BenchOp<K, T> op;
  const BenchCase(
      {required this.name, required this.description, required this.op});
}

class BenchBoxFactory<K, T> {
  final String label;
  final Future<BoxInterface<K, T>> Function() open;
  final Future<void> Function() cleanup;
  const BenchBoxFactory(
      {required this.label, required this.open, required this.cleanup});
}

enum BenchIsolation { deleteBetweenRuns, clearBetweenRuns, none }

class BenchConfig {
  final bool openOnce;
  final BenchIsolation isolation;
  final bool doWarmup;
  const BenchConfig({
    this.openOnce = false,
    this.isolation = BenchIsolation.deleteBetweenRuns,
    this.doWarmup = true,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// Macro benchmark suite
/// ─────────────────────────────────────────────────────────────────────────

typedef PreparedBlockPrepare<K, T> = Future<void> Function(
    BoxInterface<K, T> box);
typedef PreparedBlockMeasure<K, T> = Future<void> Function(
    BoxInterface<K, T> box);

class PreparedBlockBenchCase<K, T> {
  final String name;
  final String description;
  final PreparedBlockPrepare<K, T> preparePerRun;
  final PreparedBlockMeasure<K, T> measured;
  const PreparedBlockBenchCase({
    required this.name,
    required this.description,
    required this.preparePerRun,
    required this.measured,
  });
}

class MacroBenchSuite<K, T> {
  final String suiteName;
  final BenchConfig config;
  final List<PreparedBlockBenchCase<K, T>> _cases = [];
  final List<BenchBoxFactory<K, T>> _boxes = [];

  MacroBenchSuite(this.suiteName, {this.config = const BenchConfig()});

  void registerPreparedCase(PreparedBlockBenchCase<K, T> c) => _cases.add(c);
  void registerBox(BenchBoxFactory<K, T> f) {
    _boxes.add(f);
    if (!boxColumnOrder.contains(f.label)) boxColumnOrder.add(f.label);
  }

  Future<void> run(int runsPerCase) async {
    for (final c in _cases) {
      results.putIfAbsent(c.name, () => <String, BenchStats>{});
      for (final b in _boxes) {
        final runMicros = <int>[];

        BoxInterface<K, T>? shared;
        if (config.openOnce) {
          shared = await b.open();
          await shared.ensureInitialized();
          if (config.isolation != BenchIsolation.none) await shared.clear();
        }

        for (int run = 0; run < runsPerCase; run++) {
          final box = config.openOnce ? shared! : await b.open();
          if (!config.openOnce) {
            await box.ensureInitialized();
            await box.clear();
          }

          await c.preparePerRun(box);
          await box.flushBox();

          if (config.doWarmup) {
            for (int i = 0; i < kWarmupIters; i++) {
              await c.measured(box);
            }
          }

          final sw = Stopwatch()..start();
          for (int i = 0; i < kMeasureIters; i++) {
            await c.measured(box);
          }
          sw.stop();
          runMicros.add(sw.elapsedMicroseconds);

          if (!config.openOnce) {
            await _resetAfterRun(box, config.isolation);
            await box.flushBox();
            await box.closeBox();
            await b.cleanup();
          } else if (config.isolation == BenchIsolation.clearBetweenRuns) {
            await box.clear();
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

        results[c.name]![b.label] = BenchStats(runMicros);
      }
    }
  }

  Future<void> _resetAfterRun(
      BoxInterface<K, T> box, BenchIsolation iso) async {
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
/// Utility: results printing and formatting
/// ─────────────────────────────────────────────────────────────────────────

void printResultsTableTo(StringSink out) {
  if (results.isEmpty) {
    out.writeln('\n(no benchmark results)\n');
    return;
  }

  final boxCols = List<String>.from(boxColumnOrder);
  final headerCols =
      <String>['Case'] + boxCols.map((b) => '$b (avg ms)').toList()
        ..add('Best');

  final colWidths = List<int>.filled(headerCols.length, 0);
  for (int ci = 0; ci < headerCols.length; ci++) {
    colWidths[ci] = headerCols[ci].length;
  }
  void consider(String s, int ci) {
    if (s.length > colWidths[ci]) colWidths[ci] = s.length;
  }

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

      if (stats != null && (bestMs == null || avg < bestMs)) {
        bestMs = avg;
        bestBox = box;
      }
    }

    final row = <String>[
      caseName,
      ...boxCols.map((b) => msByBox[b]!),
      (bestBox ?? '-')
    ];
    for (int i = 0; i < row.length; i++) {
      consider(row[i], i);
    }
    rows.add(row);
  }

  String pad(String s, int w) => s.padRight(w);
  final sep = '─' * (colWidths.fold<int>(0, (a, b) => a + b + 3) - 1);
  out.writeln('\n$sep');
  out.writeln('📊 Hivez Benchmarks');
  out.writeln(sep);

  final header =
      List.generate(headerCols.length, (i) => pad(headerCols[i], colWidths[i]))
          .join(' │ ');
  out.writeln(header);
  out.writeln(
      List.generate(headerCols.length, (i) => ''.padRight(colWidths[i], '─'))
          .join('─┼─'));

  for (final row in rows) {
    final line =
        List.generate(row.length, (i) => pad(row[i], colWidths[i])).join(' │ ');
    out.writeln(line);
  }

  out.writeln('$sep\n');
}

void printResultsTable() => printResultsTableTo(stdout);

/// ─────────────────────────────────────────────────────────────────────────
/// Data generation
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

int _caseGroup(String name) {
  if (name.startsWith('Put many - n_')) return 0;
  if (name.startsWith('Query Search - n_')) return 1;
  return 2;
}

int _caseSize(String name) {
  final m = RegExp(r'_(\d+)$').firstMatch(name);
  return m == null ? 1 << 30 : int.parse(m.group(1)!);
}

int _caseComparator(String a, String b) {
  final ga = _caseGroup(a), gb = _caseGroup(b);
  if (ga != gb) return ga - gb;
  final sa = _caseSize(a), sb = _caseSize(b);
  if (sa != sb) return sa - sb;
  return a.compareTo(b);
}

abstract class BenchmarkConfig {
  final int runsPerCase;
  final bool runMacroBenches;
  final List<int> sizes;

  const BenchmarkConfig({
    this.runsPerCase = 20,
    this.runMacroBenches = true,
    this.sizes = const [100, 1000, 5000, 10000, 50000],
  });

  Future<void> setupHive();
  BoxInterface<int, String> createNormalBox(String name);
  BoxInterface<int, String> createIndexedBox(
    String name, {
    required String Function(String) searchableText,
  });
  String get fileName;
}

Future<void> runBenchmark(
  BenchmarkConfig config,
) async {
  await config.setupHive();
  if (!kRunMacroBenches) {
    print('Macro benchmarks disabled.');
    return;
  }
  final sizes = config.sizes;

  for (final size in sizes) {
    final suite = MacroBenchSuite<int, String>(
      'populate_suite_$size',
      config: const BenchConfig(
          openOnce: true, isolation: BenchIsolation.clearBetweenRuns),
    );

    final sizeStr = (size * kMeasureIters).toString();

    suite.registerPreparedCase(PreparedBlockBenchCase<int, String>(
      name: 'Put many - n_$sizeStr',
      description: 'putAll random $size items (batched $_writeBatch)',
      preparePerRun: (box) async {
        await box.clear();
        await box.flushBox();
      },
      measured: (box) async {
        final gen = _DeterministicData(seed: 1000 + size);
        final entries = _buildDataset(size, gen);
        await _populateWithEntries(box, entries);
      },
    ));

    suite.registerPreparedCase(PreparedBlockBenchCase<int, String>(
      name: 'Query Search - n_$sizeStr',
      description: 'search inside $size items (search only timed)',
      preparePerRun: (box) async {
        final gen = _DeterministicData(seed: 1000 + size);
        final entries = _buildDataset(size, gen);
        await _populateWithEntries(box, entries);
        await box.flushBox();
      },
      measured: (box) async {
        const q = 'lo ma ra hel';
        if (box is IndexedBox<int, String>) {
          await box.search(q);
        } else {
          await box.search(query: q, searchableText: (s) => s);
        }
      },
    ));

    suite.registerBox(BenchBoxFactory<int, String>(
      label: 'HivezBox',
      open: () async {
        final name = 'macro_pop_hivez_${Random().nextInt(1 << 32)}';
        final b = config.createNormalBox(name);
        await b.ensureInitialized();
        await b.clear();
        return b;
      },
      cleanup: () async {},
    ));

    suite.registerBox(BenchBoxFactory<int, String>(
      label: 'IndexedBox',
      open: () async {
        final name = 'macro_pop_indexed_${Random().nextInt(1 << 32)}';
        final b = config.createIndexedBox(
          name,
          searchableText: (s) => s,
        );
        await b.ensureInitialized();
        await b.clear();
        return b;
      },
      cleanup: () async {},
    ));

    await suite.run(config.runsPerCase);
  }

  final buffer = StringBuffer();
  printResultsTableTo(buffer);
  await File(config.fileName).writeAsString(buffer.toString());
  print('\n✅ Results written to benchmark_results.txt');
}
