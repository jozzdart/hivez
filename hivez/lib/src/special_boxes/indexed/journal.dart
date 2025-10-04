part of 'indexed.dart';

/// Guarantees: mark-dirty before user op; mark-clean iff op completes.
/// If the op throws, the journal remains dirty for recovery.
abstract class IndexJournal extends ConfiguredBox<String, int> {
  IndexJournal(super.config);

  Future<bool> isDirty();

  /// Executes [op] within a journaled write.
  /// - Marks dirty before running
  /// - Marks clean if and only if [op] completes successfully
  Future<R> runWrite<R>(Future<R> Function() op);

  /// Marks clean (used for explicit resets, e.g., after rebuild).
  Future<void> reset();
}

/// Meta is a small sibling box: `${dataName}__idx_meta` storing '__dirty'->1/0.
class BoxIndexJournal extends IndexJournal {
  static const _kDirtyKey = '__dirty';

  BoxIndexJournal(super.config);

  @override
  Future<bool> isDirty() async => (await get(_kDirtyKey)) == 1;

  @override
  Future<R> runWrite<R>(Future<R> Function() op) async {
    await put(_kDirtyKey, 1);
    try {
      final out = await op();
      await put(_kDirtyKey, 0);
      return out;
    } catch (_) {
      // stay dirty for recovery
      rethrow;
    }
  }

  @override
  Future<void> reset() => put(_kDirtyKey, 0);
}
