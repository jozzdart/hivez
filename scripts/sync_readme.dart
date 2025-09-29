import 'dart:io';

void main() async {
  final source = File('README.md');
  final flutterTarget = File('hivez_flutter/README.md');
  final rootTarget = File('hivez/README.md'); // ✅ root-level README

  if (!await source.exists()) {
    stderr.writeln('❌ hivez_flutter/README.md not found.');
    exit(1);
  }

  final content = await source.readAsString();

  final result = '''

## Flutter utilities for [`hivez` package. Click for the full documentation.](https://pub.dev/packages/hivez)

''';

  await flutterTarget.writeAsString(result);
  print('✅ hivez_flutter/README.md updated.');

  await rootTarget.writeAsString(content);
  print('✅ Root README.md updated from hivez_flutter.');
}
