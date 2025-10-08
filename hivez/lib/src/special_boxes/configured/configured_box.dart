library;

import 'package:hivez/src/boxes/boxes.dart';
import 'package:hivez/src/builders/builders.dart';

part 'extensions.dart';

class ConfiguredBox<K, T> extends BoxDecorator<K, T> {
  final BoxConfig config;

  ConfiguredBox(
    this.config,
  ) : super(config.createBox<K, T>());
}
