import 'package:hivez/hivez.dart';

import '../benchmark_system.dart';
import '../test_setup.dart';

class BenchmarkConfigIsolated1M extends BenchmarkConfig {
  const BenchmarkConfigIsolated1M()
      : super(sizes: const [1000000], runsPerCase: 2);

  @override
  String get fileName => 'results_isolated_1m.txt';

  @override
  Future<void> setupHive() => setupIsolatedHiveTest();

  @override
  BoxInterface<int, String> createNormalBox(String name) =>
      HivezBoxIsolatedLazy<int, String>(name);

  @override
  BoxInterface<int, String> createIndexedBox(
    String name, {
    required String Function(String) searchableText,
  }) =>
      IndexedBox<int, String>(
        name,
        type: BoxType.isolatedLazy,
        searchableText: (s) => s,
      );
}

Future<void> main() async {
  runBenchmark(const BenchmarkConfigIsolated1M());
}
