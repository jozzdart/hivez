import 'dart:io' show File;
import 'dart:math' as math;

import 'package:hive_ce/hive.dart';
import 'package:hivez/src/boxes/boxes.dart';
import 'package:hivez/src/builders/builders.dart';
import 'package:hivez/src/exceptions/box_exception.dart';
import 'package:hivez/src/special_boxes/configured/configured_box.dart';

part 'engine.dart';
part 'journal.dart';
part 'cache.dart';
part 'search.dart';
part 'analyzer.dart';
part 'extensions.dart';
part 'exceptions.dart';
part 'lock.dart';

class IndexedBox<K, T> extends ConfiguredBox<K, T> {
  final IndexEngine<K, T> _engine;
  final IndexJournal _journal;
  final TokenKeyCache<K> _cache;
  late final IndexedBoxLock _lock;
  late final IndexSearcher<K, T> _searcher;

  IndexedBox(
    super.config, {
    required String Function(T) searchableText,
    Analyzer analyzer = Analyzer.prefix,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
    TextAnalyzer<T>? overrideAnalyzer,
  })  : _engine = IndexEngine<K, T>(
          config.copyWith(name: '${config.name}__idx', logger: null),
          analyzer: overrideAnalyzer ?? analyzer.analyzer(searchableText),
          matchAllTokens: matchAllTokens,
        ),
        _journal = BoxIndexJournal(
          config.copyWith(name: '${config.name}__idx_meta', logger: null),
        ),
        _cache = tokenCacheCapacity <= 0
            ? NoopTokenKeyCache<K>()
            : LruTokenKeyCache<K>(tokenCacheCapacity.clamp(1, 10000)) {
    _searcher = IndexSearcher<K, T>(
      engine: _engine,
      cache: _cache,
      analyzer: overrideAnalyzer ?? analyzer.analyzer(searchableText),
      verifyMatches: verifyMatches,
      ensureReady: ensureInitialized,
      getValue: super.get,
      keyComparator: keyComparator,
    );
    _lock = IndexedBoxLock(this);
  }

  factory IndexedBox.create(
    String name, {
    BoxType type = BoxType.regular,
    Analyzer analyzer = Analyzer.prefix,
    required String Function(T) searchableText,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
    TextAnalyzer<T>? overrideAnalyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) =>
      IndexedBox<K, T>(
        BoxConfig(
          name,
          type: type,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
        searchableText: searchableText,
        analyzer: analyzer,
        overrideAnalyzer: overrideAnalyzer,
        matchAllTokens: matchAllTokens,
        tokenCacheCapacity: tokenCacheCapacity,
        verifyMatches: verifyMatches,
        keyComparator: keyComparator,
      );

  // -----------------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------------

  @override
  bool get isInitialized =>
      super.isInitialized && _engine.isInitialized && _journal.isInitialized;

  @override
  Future<void> ensureInitialized() async {
    // Open main data + journal first (we need path/length and snapshot)
    await super.ensureInitialized();
    await _journal.ensureInitialized();
    // Decide if we should rebuild before touching the engine.
    var needsRebuild = await _shouldRebuild();
    if (needsRebuild) {
      // Optional light probe to avoid unnecessary rebuilds if desired:
      final ok = await _quickIndexProbe(probes: 16); // set e.g. 16 to enable
      needsRebuild = !ok;
    }

    // Now open engine (index box)
    await _engine.ensureInitialized();

    if (needsRebuild) {
      config.logger?.call('Index preflight mismatch → rebuilding index');
      try {
        await rebuildIndex();
        await _journal.reset(); // mark clean
        await _stampSnapshot(); // store fresh snapshot
      } catch (e, st) {
        throw IndexRebuildFailed(boxName: name, cause: e, stackTrace: st);
      }
      return;
    }
  }

  // -----------------------------------------------------------------------------
  // Disk / Close / Flush / Compact  (non-mutating; no dirty toggles)
  // -----------------------------------------------------------------------------
  @override
  Future<void> flushBox() async {
    await _lock.operation("FLUSH_BOX").run(() async {
      await _engine.flushBox();
      await _journal.flushBox();
      await super.flushBox();
    });
  }

  @override
  Future<void> compactBox() async {
    await _lock.operation("COMPACT_BOX").run(() async {
      await _engine.compactBox();
      await _journal.compactBox();
      await super.compactBox();
    });
  }

  @override
  Future<void> closeBox() async {
    await _lock.operation("CLOSE_BOX").run(() async {
      await _engine.flushBox();
      await _journal.flushBox();
      await super.flushBox();
      _cache.clear();
      await _engine.closeBox();
      await _journal.closeBox();
      await super.closeBox();
    });
  }

  @override
  Future<void> deleteFromDisk() async {
    await _lock.bypassJournal.operation("DELETE_FROM_DISK").run(() async {
      _cache.clear();
      await _engine.deleteFromDisk();
      await _journal.deleteFromDisk();
      await super.deleteFromDisk();
    });
  }

  /// Clears runtime caches + resets journal (no persistent data loss).
  Future<void> resetRuntimeState() async {
    await _lock.operation("RESET_RUNTIME_STATE").run(() async {
      _cache.clear();
      await _journal.reset();
    });
  }

  @override
  Future<int> estimateSizeBytes() async {
    final size = await super.estimateSizeBytes();
    final engineSize = await _engine.estimateSizeBytes();
    final journalSize = await _journal.estimateSizeBytes();
    return size + engineSize + journalSize;
  }

  // -----------------------------------------------------------------------------
  // Write path (all wrapped in _writeTxn)
  // -----------------------------------------------------------------------------
  @override
  Future<void> put(K key, T value) => _lock.operation("PUT").run(() async {
        final old = await super.get(key);
        await super.put(key, value);
        await _engine.onPut(key, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
        await _stampSnapshot();
      });

  @override
  Future<void> putAll(Map<K, T> entries) {
    if (entries.isEmpty) return Future.value();
    return _lock.operation("PUT_ALL").run(() async {
      final olds = <K, T>{};
      for (final e in entries.entries) {
        final v = await super.get(e.key);
        if (v != null) olds[e.key] = v;
      }
      await super.putAll(entries);
      await _engine.onPutMany(entries, olds: olds);
      for (final v in olds.values) {
        _invalidateTokensFor(v);
      }
      for (final v in entries.values) {
        _invalidateTokensFor(v);
      }
      await _stampSnapshot();
    });
  }

  @override
  Future<int> add(T value) => _lock.operation("ADD").run(() async {
        final id = await super.add(value);
        await _engine.onPut(id as K, value);
        _invalidateTokensFor(value);
        await _stampSnapshot();
        return id;
      });

  @override
  Future<void> addAll(Iterable<T> values) {
    if (values.isEmpty) return Future.value();
    return _lock.operation("ADD_ALL").run(() async {
      final news = <K, T>{};
      for (final v in values) {
        final id = await super.add(v);
        news[id as K] = v;
        _invalidateTokensFor(v);
      }
      await _engine.onPutMany(news);
      await _stampSnapshot();
    });
  }

  @override
  Future<void> delete(K key) => _lock.operation("DELETE").run(() async {
        final old = await super.get(key);
        await super.delete(key);
        if (old != null) {
          await _engine.onDelete(key, oldValue: old);
          _invalidateTokensFor(old);
        }
        await _stampSnapshot();
      });

  @override
  Future<void> deleteAll(Iterable<K> keys) {
    final unique = keys is Set<K> ? keys : keys.toSet();
    if (unique.isEmpty) return Future.value();
    return _lock.operation("DELETE_ALL").run(() async {
      final olds = <K, T>{};
      for (final k in unique) {
        final v = await super.get(k);
        if (v != null) olds[k] = v;
      }
      await super.deleteAll(unique);
      if (olds.isNotEmpty) {
        await _engine.onDeleteMany(olds);
        for (final v in olds.values) {
          _invalidateTokensFor(v);
        }
      }
      await _stampSnapshot();
    });
  }

  @override
  Future<void> deleteAt(int index) =>
      _lock.operation("DELETE_AT").run(() async {
        final k = await super.keyAt(index);
        final old = await super.get(k);
        await super.deleteAt(index);
        if (old != null) {
          await _engine.onDelete(k, oldValue: old);
          _invalidateTokensFor(old);
        }
        await _stampSnapshot();
      });

  @override
  Future<void> clear() => _lock.operation("CLEAR").run(() async {
        await super.clear();
        await _engine.clear();
        _cache.clear();
        await _stampSnapshot();
      });

  @override
  Future<void> putAt(int index, T value) =>
      _lock.operation("PUT_AT").run(() async {
        final k = await super.keyAt(index);
        final old = await super.get(k);
        await super.putAt(index, value);
        await _engine.onPut(k, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
        await _stampSnapshot();
      });

  @override
  Future<bool> moveKey(K oldKey, K newKey) =>
      _lock.operation("MOVE_KEY").run(() async {
        final v = await super.get(oldKey);
        if (v == null) return false;
        final moved = await super.moveKey(oldKey, newKey);
        if (moved) {
          await _engine.onDelete(oldKey, oldValue: v);
          await _engine.onPut(newKey, v);
          _invalidateTokensFor(v);
          await _stampSnapshot();
        }
        return moved;
      });

  // Values
  Future<List<T>> search(String query, {int? limit, int offset = 0}) =>
      _searcher.values(query, limit: limit, offset: offset);

  // Keys
  Future<List<K>> searchKeys(String query, {int? limit, int offset = 0}) =>
      _searcher.keys(query, limit: limit, offset: offset);

  // Streams
  Stream<K> searchKeysStream(String query) => _searcher.keysStream(query);
  Stream<T> searchStream(String query) => _searcher.valuesStream(query);

  // -----------------------------------------------------------------------------
  // Rebuild index (journaled)
  // -----------------------------------------------------------------------------
  Future<void> rebuildIndex(
      {void Function(double progress)? onProgress}) async {
    await _engine.clear();
    _cache.clear();
    final total = await length;
    var processed = 0;
    const chunk = 500;
    final buffer = <String, Set<K>>{};
    Future<void> flush() async {
      if (buffer.isEmpty) return;
      final payload = <String, List<K>>{};
      buffer.forEach((token, set) {
        if (set.isNotEmpty) payload[token] = set.toList(growable: false);
      });
      if (payload.isNotEmpty) await _engine.putAll(payload);
      buffer.clear();
    }

    await foreachValue((k, v) async {
      for (final t in _analyze(v)) {
        (buffer[t] ??= <K>{}).add(k);
      }
      processed++;
      if (processed % chunk == 0) {
        await flush();
        onProgress?.call(total == 0 ? 1.0 : processed / total);
      }
    });
    await flush();
    onProgress?.call(1.0);
    await _stampSnapshot();
  }

  // --- Snapshot / signature helpers ------------------------------------------

  // Simple 32-bit FNV-1a to store signatures as ints in the journal.
  static int _hash32(String s) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;
    for (final codeUnit in s.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  int _analyzerSigHash() {
    final a = _engine.analyzer;
    final b = StringBuffer()..write(a.runtimeType.toString());
    // capture config knobs so index schema changes trigger rebuild
    if (a is PrefixTextAnalyzer<T>) {
      b
        ..write('|minPrefix=')
        ..write(a.minPrefix);
    }
    if (a is NGramTextAnalyzer<T>) {
      b
        ..write('|minN=')
        ..write(a.minN)
        ..write('|maxN=')
        ..write(a.maxN);
    }
    b
      ..write('|matchAll=')
      ..write(_engine.matchAllTokens);
    return _hash32(b.toString());
  }

  Future<IndexSnapshot> _currentSnapshot() async {
    int? mtimeMs;
    int? sizeBytes;
    try {
      final p = path;
      if (p != null) {
        final st = await File(p).stat();
        mtimeMs = st.modified.millisecondsSinceEpoch;
        sizeBytes = st.size;
      }
    } catch (_) {
      // Platforms without File I/O or transient errors — ignore
    }
    final count = await length;
    return IndexSnapshot(
      dataMtimeMs: mtimeMs,
      dataSizeBytes: sizeBytes,
      entries: count,
      analyzerSigHash: _analyzerSigHash(),
      indexVersion: 1,
    );
  }

  Future<void> _stampSnapshot() async {
    final snap = await _currentSnapshot();
    await _journal.writeSnapshot(
      dataMtimeMs: snap.dataMtimeMs,
      dataSizeBytes: snap.dataSizeBytes,
      entries: snap.entries ?? 0,
      analyzerSigHash: snap.analyzerSigHash ?? 0,
      indexVersion: 1,
    );
  }

  Future<bool> _shouldRebuild() async {
    // If journal says "dirty", we must rebuild.
    if (await _journal.isDirty()) return true;

    final saved = await _journal.readSnapshot();
    // No snapshot recorded yet => likely first run with IndexedBox
    if (saved == null) return true;

    final now = await _currentSnapshot();

    // Any schema/shape changes → rebuild
    if (saved.analyzerSigHash != now.analyzerSigHash) return true;

    // Entries change with out-of-band writes; IndexedBox stamps after writes.
    if (saved.entries != now.entries) return true;

    // If file stats are present, use them as a tripwire (cheap, very reliable).
    if (saved.dataMtimeMs != null &&
        now.dataMtimeMs != null &&
        saved.dataMtimeMs != now.dataMtimeMs) {
      return true;
    }
    if (saved.dataSizeBytes != null &&
        now.dataSizeBytes != null &&
        saved.dataSizeBytes != now.dataSizeBytes) {
      return true;
    }

    return false;
  }

  // Optional: tiny probe to double-check before a rebuild (set probes>0 to use)
  Future<bool> _quickIndexProbe({int probes = 0}) async {
    if (probes <= 0) return true; // skip probe
    final total = await length;
    if (total == 0) return true;

    final step = math.max(1, total ~/ probes);
    for (int i = 0, seen = 0; i < total && seen < probes; i += step, seen++) {
      final k = await keyAt(i);
      final v = await get(k);
      if (v == null) continue;
      final tokens = _analyze(v).toSet();
      for (final t in tokens.take(8)) {
        // cap per item to keep it cheap
        final keys = await _engine.readToken(t);
        if (!keys.contains(k)) return false; // stale
      }
    }
    return true;
  }

  // -----------------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------------
  Iterable<String> _analyze(T v) => _engine.analyzer.analyze(v);

  void _invalidateTokensFor(T? value) {
    if (value == null) return;
    _cache.invalidateTokens(_analyze(value));
  }

  @override
  bool operator ==(Object other) =>
      other is IndexedBox<K, T> &&
      other._engine == _engine &&
      other._journal == _journal &&
      other._cache == _cache &&
      config.name == other.config.name;

  @override
  int get hashCode =>
      _engine.hashCode ^ _journal.hashCode ^ _cache.hashCode ^ super.hashCode;

  @override
  String toString() =>
      '${super.toString()} <[ engine: $_engine, journal: $_journal, cache: $_cache ]>';
}
