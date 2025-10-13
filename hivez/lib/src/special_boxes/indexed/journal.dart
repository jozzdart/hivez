part of 'indexed.dart';

class IndexSnapshot {
  final int? dataMtimeMs;
  final int? dataSizeBytes;
  final int? entries;
  final int? analyzerSigHash;
  final int? indexVersion;

  const IndexSnapshot({
    this.dataMtimeMs,
    this.dataSizeBytes,
    this.entries,
    this.analyzerSigHash,
    this.indexVersion,
  });
}

/// Guarantees: mark-dirty before user op; mark-clean iff op completes.
/// If the op throws, the journal remains dirty for recovery.
abstract class IndexJournal extends Box<String, int> {
  IndexJournal(
    super.name, {
    super.type,
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  Future<bool> isDirty();

  /// Executes [op] within a journaled write.
  Future<R> runWrite<R>(Future<R> Function() op);

  /// Marks clean (used for explicit resets, e.g., after rebuild).
  Future<void> reset();

  /// Marks dirty (used for explicit marks, e.g., after put/delete).
  Future<void> markDirty();

  // --- NEW: snapshot API ------------------------------------------------------
  Future<void> writeSnapshot({
    int? dataMtimeMs,
    int? dataSizeBytes,
    required int entries,
    required int analyzerSigHash,
    int indexVersion = 1,
  });

  Future<IndexSnapshot?> readSnapshot();
}

/// Meta is a small sibling box: `${dataName}__idx_meta`.
class BoxIndexJournal extends IndexJournal {
  static const _kDirtyKey = '__dirty';

  static const _kMtime = '__data_mtime';
  static const _kSize = '__data_size';
  static const _kEntries = '__data_entries';
  static const _kSig = '__analyzer_sig';
  static const _kVer = '__idx_ver';

  BoxIndexJournal(
    super.name, {
    super.type,
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
  });

  @override
  Future<bool> isDirty() async => (await nativeBox.get(_kDirtyKey)) == 1;

  @override
  Future<R> runWrite<R>(Future<R> Function() op) async {
    await markDirty();
    try {
      final out = await op();
      await nativeBox.put(_kDirtyKey, 0);
      return out;
    } catch (_) {
      // stay dirty for recovery
      rethrow;
    }
  }

  @override
  Future<void> reset() => nativeBox.put(_kDirtyKey, 0);

  @override
  Future<void> markDirty() => nativeBox.put(_kDirtyKey, 1);

  @override
  Future<void> writeSnapshot({
    int? dataMtimeMs,
    int? dataSizeBytes,
    required int entries,
    required int analyzerSigHash,
    int indexVersion = 1,
  }) async {
    final payload = <String, int>{
      _kEntries: entries,
      _kSig: analyzerSigHash,
      _kVer: indexVersion,
    };

    if (dataMtimeMs != null) payload[_kMtime] = dataMtimeMs;
    if (dataSizeBytes != null) payload[_kSize] = dataSizeBytes;

    await nativeBox.putAll(payload);
  }

  @override
  Future<IndexSnapshot?> readSnapshot() async {
    // If no entries recorded yet, treat as missing snapshot
    final entries = await nativeBox.get(_kEntries);
    if (entries == null) return null;

    return IndexSnapshot(
      dataMtimeMs: await nativeBox.get(_kMtime),
      dataSizeBytes: await nativeBox.get(_kSize),
      entries: entries,
      analyzerSigHash: await nativeBox.get(_kSig),
      indexVersion: await nativeBox.get(_kVer),
    );
  }
}
