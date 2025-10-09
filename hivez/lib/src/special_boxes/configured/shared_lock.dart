part of 'configured_box.dart';

class SharedLock {
  final Lock _lock;

  Future<void> Function(String opName, Object error, StackTrace stack)? onError;

  SharedLock({
    Lock? overrideLock,
  }) : _lock = overrideLock ?? Lock();

  Future<R> runOperation<R>(Future<R> Function() body, {String? name}) async {
    try {
      return await _run(body);
    } catch (e, st) {
      if (onError != null) {
        await onError!(name ?? 'Unknown', e, st);
      }
      rethrow;
    }
  }

  @internal
  Future<R> runner<R>(Future<R> Function() body) => body();

  // Small helper so every write uses the same discipline.
  Future<R> _run<R>(Future<R> Function() body) =>
      _lock.synchronized(() => runner(body));
}

extension SharedLockExtension on SharedLock {
  Lock get internalLock => _lock;
}
