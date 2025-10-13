import 'package:hivez/hivez.dart';

import '../benchmark_system.dart';
import '../test_setup.dart';

class BenchmarkConfigNormal1M extends BenchmarkConfig {
  const BenchmarkConfigNormal1M()
      : super(sizes: const [1000000], runsPerCase: 2);

  @override
  String get fileName => 'results_normal_1m.txt';

  @override
  Future<void> setupHive() => setupHiveTest();

  @override
  BoxInterface<int, String> createNormalBox(String name) =>
      HivezBoxLazy<int, String>(name);

  @override
  BoxInterface<int, String> createIndexedBox(
    String name, {
    required String Function(String) searchableText,
  }) =>
      IndexedBox<int, String>(
        name,
        type: BoxType.lazy,
        searchableText: (s) => s,
      );
}

Future<void> main() async {
  runBenchmark(const BenchmarkConfigNormal1M());
}
