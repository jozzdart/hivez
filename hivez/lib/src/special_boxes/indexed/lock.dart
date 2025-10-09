part of 'indexed.dart';

class IndexedBoxLock extends SharedLock {
  final IndexedBox indexedBox;

  IndexedBoxLock(this.indexedBox, {super.overrideLock});

  @override
  Future<R> runner<R>(Future<R> Function() body) async {
    return await indexedBox._journal.runWrite(body);
  }

  @override
  Future<void> Function(String opName, Object error, StackTrace stack)?
      get onError => _onError;

  Future<void> _onError(String opName, Object error, StackTrace stack) async =>
      indexedBox.logger?.call(_msg(opName, error, stack));

  String _msg(String opName, Object error, StackTrace stack) {
    return '[ERROR with Indexed Box: ${indexedBox.name}] [$opName] Unexpected error: $error\n$stack';
  }
}

class IndexedBoxLockBypassJournal extends SharedLock {
  final IndexedBox indexedBox;

  IndexedBoxLockBypassJournal(this.indexedBox, {super.overrideLock});

  @override
  Future<void> Function(String opName, Object error, StackTrace stack)?
      get onError => _onError;

  Future<void> _onError(String opName, Object error, StackTrace stack) async =>
      indexedBox.logger?.call(_msg(opName, error, stack));

  String _msg(String opName, Object error, StackTrace stack) {
    return '[ERROR with Indexed Box: ${indexedBox.name}] [$opName] Unexpected error: $error\n$stack';
  }
}

extension IndexedBoxLockExtension on IndexedBoxLock {
  IndexedBoxLockBypassJournal get bypassJournal =>
      IndexedBoxLockBypassJournal(indexedBox, overrideLock: internalLock);
}
