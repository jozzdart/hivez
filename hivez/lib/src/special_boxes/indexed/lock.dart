part of 'indexed.dart';

class IndexedBoxLocker extends SharedLock {
  final IndexedBox indexedBox;

  IndexedBoxLocker(this.indexedBox);

  @override
  Future<R> runner<R>(Future<R> Function() body) async {
    await indexedBox.ensureInitialized();
    return await indexedBox._journal.runWrite(body);
  }

  @override
  Future<void> Function(String opName, Object error, StackTrace stack)?
      get onError => _onError;

  Future<void> _onError(String opName, Object error, StackTrace stack) async =>
      indexedBox.config.logger?.call(_msg(opName, error, stack));

  String _msg(String opName, Object error, StackTrace stack) {
    return '[ERROR with Indexed Box: ${indexedBox.name}] [$opName] Unexpected error: $error\n$stack';
  }
}
