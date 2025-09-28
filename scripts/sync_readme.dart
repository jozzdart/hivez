import 'dart:io';

void main() async {
  final source = File('README.md');
  final flutterTarget = File('hivez_flutter/README.md');
  final rootTarget = File('README.md'); // ✅ root-level README

  if (!await source.exists()) {
    stderr.writeln('❌ hivez_flutter/README.md not found.');
    exit(1);
  }

  final content = await source.readAsString();

  final result = '''
# hivez_flutter

🧩 Flutter utilities for [`hivez`](https://pub.dev/packages/hivez), including Hivez and Hive CE Flutter bindings.

---

The following is adapted from the main [`hivez`](https://pub.dev/packages/hivez) documentation:

<!-- hivez:sync-start -->

$content

<!-- hivez:sync-end -->
''';

  await flutterTarget.writeAsString(result);
  print('✅ hivez_flutter/README.md updated.');

  await rootTarget.writeAsString(content);
  print('✅ Root README.md updated from hivez_flutter.');
}
