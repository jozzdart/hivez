part of 'configured_box.dart';

class LockedOperation {
  final String? name;
  final SharedLock _lock;

  const LockedOperation({
    this.name,
    required SharedLock lock,
  }) : _lock = lock;

  Future<T> run<T>(Future<T> Function() operation) async {
    return _lock.runOperation(operation, name: name);
  }
}
