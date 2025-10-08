part of 'configured_box.dart';

extension CreateConfiguredBoxFromConfig on BoxConfig {
  ConfiguredBox<K, T> createConfiguredBox<K, T>() => ConfiguredBox(this);
}

extension CreateLockedOperationFromLock on SharedLock {
  LockedOperation operation(String? name) =>
      LockedOperation(lock: this, name: name);
}
