import 'package:hivez/hivez.dart';

import '../benchmark_system.dart';
import '../test_setup.dart';

class BenchmarkConfigNormal extends BenchmarkConfig {
  const BenchmarkConfigNormal() : super(runsPerCase: 40);

  @override
  String get fileName => 'results_normal.txt';

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
  runBenchmark(const BenchmarkConfigNormal());
}
