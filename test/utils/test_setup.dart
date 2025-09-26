import 'dart:io';

import 'package:hive_ce_flutter/adapters.dart';

Future<void> setupIsolatedHiveTest() async {
  final testDir = Directory('${Directory.systemTemp.path}/hivez_test');
  if (!testDir.existsSync()) {
    testDir.createSync(recursive: true);
  }
  await IsolatedHive.init('isolated_hive_test_hivez');
}

Future<void> setupHiveTest() async {
  final testDir = Directory('${Directory.systemTemp.path}/hivez_test');
  if (!testDir.existsSync()) {
    testDir.createSync(recursive: true);
  }
  Hive.init(testDir.path);
}
