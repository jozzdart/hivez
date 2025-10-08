part of 'configured_box.dart';

extension CreateConfiguredBoxFromConfig on BoxConfig {
  ConfiguredBox<K, T> createConfiguredBox<K, T>() => ConfiguredBox(this);
}
