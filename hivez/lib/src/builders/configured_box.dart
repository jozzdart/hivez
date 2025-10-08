part of 'builders.dart';

class ConfiguredBox<K, T> extends BoxDecorator<K, T> {
  final BoxConfig config;

  ConfiguredBox(
    this.config,
  ) : super(config.createBox<K, T>());
}
