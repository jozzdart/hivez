import 'dart:io' show File;
import 'dart:math' as math;

import 'package:hive_ce/hive.dart' show HiveCipher;
import 'package:hivez/src/boxes/boxes.dart';
import 'package:hivez/src/builders/builders.dart';
import 'package:hivez/src/core/core.dart';
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

/// A [Box] implementation that provides full-text search and secondary indexing.
///
/// [IndexedBox] maintains a secondary index for fast text search and token-based
/// lookups. It automatically keeps the index in sync with the main data, and
/// supports rebuilding the index if the schema or data changes out-of-band.
///
/// Type parameters:
///   - [K]: The key type (e.g., int, String).
///   - [T]: The value type (your data model).
///
/// Example usage:
/// ```dart
/// final box = IndexedBox<int, MyModel>(
///   'myBox',
///   searchableText: (m) => m.title,
/// );
/// final results = await box.search('query');
/// ```
class IndexedBox<K, T> extends Box<K, T> {
  /// The underlying index engine responsible for token-to-key mapping.
  final IndexEngine<K, T> _engine;

  /// The journal for tracking index state and snapshots.
  final IndexJournal _journal;

  /// In-memory cache for token-to-key lookups.
  final TokenKeyCache<K> _cache;

  /// Lock for synchronizing operations.
  late final IndexedBoxLockJournal _lock;

  /// Searcher for executing queries over the index.
  late final IndexSearcher<K, T> _searcher;

  /// Creates an [IndexedBox] with the given configuration.
  ///
  /// [searchableText] extracts the text to be indexed from each value.
  /// [analyzer] controls how text is tokenized (e.g., prefix, n-gram).
  /// [overrideAnalyzer] can be used to provide a custom analyzer.
  /// [matchAllTokens] requires all tokens to match for a result.
  /// [tokenCacheCapacity] sets the LRU cache size for token lookups.
  /// [verifyMatches] enables value verification for search results.
  /// [keyComparator] provides a custom sort for search results.
  IndexedBox(
    super.name, {
    required String Function(T) searchableText,
    super.type,
    Analyzer analyzer = Analyzer.prefix,
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
    TextAnalyzer<T>? overrideAnalyzer,
  })  : _engine = IndexEngine<K, T>(
          '${name}__idx',
          type: type,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: null,
          analyzer: overrideAnalyzer ?? analyzer.analyzer(searchableText),
          matchAllTokens: matchAllTokens,
        ),
        _journal = BoxIndexJournal(
          '${name}__idx_meta',
          type: type,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: null,
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
      getValue: nativeBox.get,
      getManyValues: nativeBox.getMany,
      keyComparator: keyComparator,
    );
    _lock = IndexedBoxLockJournal(this);
  }

  /// Creates an [IndexedBox] from a [BoxConfig].
  ///
  /// This is a convenience factory for constructing an [IndexedBox] using
  /// a configuration object.
  factory IndexedBox.fromConfig(
    BoxConfig config, {
    Analyzer analyzer = Analyzer.prefix,
    required String Function(T) searchableText,
    TextAnalyzer<T>? overrideAnalyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) =>
      IndexedBox<K, T>(
        config.name,
        type: config.type,
        encryptionCipher: config.encryptionCipher,
        crashRecovery: config.crashRecovery,
        path: config.path,
        collection: config.collection,
        logger: config.logger,
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

  /// Ensures the box, index, and journal are initialized and up-to-date.
  ///
  /// If the index is out-of-date or the schema has changed, the index is rebuilt.
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

  /// Flushes all data and index changes to disk.
  @override
  Future<void> flushBox() async {
    await _lock.operation("FLUSH_BOX").run(() async {
      await _engine.nativeBox.flushBox();
      await _journal.nativeBox.flushBox();
      await nativeBox.flushBox();
    });
  }

  /// Compacts the box and its index/journal to reclaim disk space.
  @override
  Future<void> compactBox() async {
    await _lock.operation("COMPACT_BOX").run(() async {
      await _engine.nativeBox.compactBox();
      await _journal.nativeBox.compactBox();
      await nativeBox.compactBox();
    });
  }

  /// Closes the box and all associated index/journal resources.
  @override
  Future<void> closeBox() async {
    await flushBox();
    await _lock.bypassJournal.operation("CLOSE_BOX").run(() async {
      _cache.clear();
      await _engine.nativeBox.closeBox();
      await _journal.nativeBox.closeBox();
      await nativeBox.closeBox();
    });
  }

  /// Deletes the box and all index/journal data from disk.
  @override
  Future<void> deleteFromDisk() async {
    await _lock.bypassJournal.operation("DELETE_FROM_DISK").run(() async {
      _cache.clear();
      await _engine.nativeBox.deleteFromDisk();
      await _journal.nativeBox.deleteFromDisk();
      await nativeBox.deleteFromDisk();
    });
  }

  /// Clears runtime caches and resets the journal.
  ///
  /// This does not delete persistent data, but resets in-memory state and
  /// marks the index as needing a rebuild.
  Future<void> resetRuntimeState() async {
    await _lock.operation("RESET_RUNTIME_STATE").run(() async {
      _cache.clear();
      await _journal.reset();
    });
  }

  /// Estimates the total size in bytes of the box, index, and journal.
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

  /// Inserts or updates a value for the given [key], updating the index.
  @override
  Future<void> put(K key, T value) => _lock.operation("PUT").run(() async {
        final old = await nativeBox.get(key);
        await nativeBox.put(key, value);
        await _engine.onPut(key, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
        await _stampSnapshot();
      });

  /// Inserts or updates multiple entries, updating the index.
  @override
  Future<void> putAll(Map<K, T> entries) {
    if (entries.isEmpty) return Future.value();
    return _lock.operation("PUT_ALL").run(() async {
      final olds = <K, T>{};
      for (final e in entries.entries) {
        final v = await nativeBox.get(e.key);
        if (v != null) olds[e.key] = v;
      }
      await nativeBox.putAll(entries);
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

  /// Replaces all data in the box with the given [entries].
  ///
  /// This operation clears the box and its index, then writes and re-indexes
  /// the provided entries in a single transaction. It is much faster than
  /// calling [clear] followed by [putAll], because it avoids any `get` calls
  /// and minimizes index operations.
  ///
  /// ⚠️ Note: This is a destructive operation — all existing data will be lost.
  @override
  Future<void> replaceAll(Map<K, T> entries) {
    return _lock.operation("REPLACE_ALL").run(() async {
      await nativeBox.clear();
      await _engine.nativeBox.clear();
      _cache.clear();

      if (entries.isEmpty) {
        await _stampSnapshot();
        return;
      }

      await nativeBox.putAll(entries);
      await _engine.onPutMany(entries);

      for (final value in entries.values) {
        _invalidateTokensFor(value);
      }

      await _stampSnapshot();
    });
  }

  /// Adds a value and returns its generated key, updating the index.
  @override
  Future<int> add(T value) {
    if (K is int) {
      return _lock.operation("ADD").run(() async {
        final id = await nativeBox.add(value);
        await _engine.onPut(id as K, value);
        _invalidateTokensFor(value);
        await _stampSnapshot();
        return id;
      });
    } else {
      throw UnsupportedError('add is not supported for non-int keys');
    }
  }

  /// Adds multiple values, updating the index.
  @override
  Future<Iterable<int>> addAll(Iterable<T> values) {
    if (K is int) {
      if (values.isEmpty) return Future.value(const <int>[]);
      return _lock.operation("ADD_ALL").run(() async {
        final news = <K, T>{};
        final ids = await nativeBox.addAll(values);

        _iterateTogether<int, T>(ids.iterator, values.iterator, (id, v) {
          news[id as K] = v;
          _invalidateTokensFor(v);
        });

        await _engine.onPutMany(news);
        await _stampSnapshot();
        return news.keys.cast<int>();
      });
    } else {
      throw UnsupportedError('addAll is not supported for non-int keys');
    }
  }

  /// Deletes the value for the given [key], updating the index.
  @override
  Future<void> delete(K key) => _lock.operation("DELETE").run(() async {
        final old = await nativeBox.get(key);
        await nativeBox.delete(key);
        if (old != null) {
          await _engine.onDelete(key, oldValue: old);
          _invalidateTokensFor(old);
        }
        await _stampSnapshot();
      });

  /// Deletes all values for the given [keys], updating the index.
  @override
  Future<void> deleteAll(Iterable<K> keys) {
    final unique = keys is Set<K> ? keys : keys.toSet();
    if (unique.isEmpty) return Future.value();
    return _lock.operation("DELETE_ALL").run(() async {
      final olds = <K, T>{};
      for (final k in unique) {
        final v = await nativeBox.get(k);
        if (v != null) olds[k] = v;
      }
      await nativeBox.deleteAll(unique);
      if (olds.isNotEmpty) {
        await _engine.onDeleteMany(olds);
        for (final v in olds.values) {
          _invalidateTokensFor(v);
        }
      }
      await _stampSnapshot();
    });
  }

  /// Deletes the value at the given [index], updating the index.
  @override
  Future<void> deleteAt(int index) =>
      _lock.operation("DELETE_AT").run(() async {
        final k = await nativeBox.keyAt(index);
        final old = await nativeBox.getAt(index);
        await nativeBox.deleteAt(index);
        if (old != null) {
          await _engine.onDelete(k as K, oldValue: old);
          _invalidateTokensFor(old);
        }
        await _stampSnapshot();
      });

  /// Clears all values and index data.
  @override
  Future<void> clear() => _lock.operation("CLEAR").run(() async {
        await nativeBox.clear();
        await _engine.nativeBox.clear();
        _cache.clear();
        await _stampSnapshot();
      });

  /// Updates the value at the given [index], updating the index.
  @override
  Future<void> putAt(int index, T value) =>
      _lock.operation("PUT_AT").run(() async {
        final k = await nativeBox.keyAt(index);
        if (k == null) return;
        final old = await nativeBox.getAt(index);
        await nativeBox.putAt(index, value);
        await _engine.onPut(k, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
        await _stampSnapshot();
      });

  /// Moves a value from [oldKey] to [newKey], updating the index.
  ///
  /// Returns true if the move was successful.
  @override
  Future<bool> moveKey(K oldKey, K newKey) =>
      _lock.operation("MOVE_KEY").run(() async {
        final v = await nativeBox.get(oldKey);
        if (v == null) return false;
        final moved = await nativeBox.moveKey(oldKey, newKey);

        if (moved) {
          await _engine.onDelete(oldKey, oldValue: v);
          await _engine.onPut(newKey, v);
          _invalidateTokensFor(v);
          await _stampSnapshot();
        }
        return moved;
      });

  /// Searches for values matching the [query] string.
  ///
  /// [limit] restricts the number of results, [offset] skips the first N results.
  Future<List<T>> search(String query, {int? limit, int offset = 0}) =>
      _searcher.values(query, limit: limit, offset: offset);

  /// Searches for keys of values matching the [query] string.
  ///
  /// [limit] restricts the number of results, [offset] skips the first N results.
  Future<List<K>> searchKeys(String query, {int? limit, int offset = 0}) =>
      _searcher.keys(query, limit: limit, offset: offset);

  /// Returns a stream of keys matching the [query] string.
  Stream<K> searchKeysStream(String query) => _searcher.keysStream(query);

  /// Returns a stream of values matching the [query] string.
  Stream<T> searchStream(String query) => _searcher.valuesStream(query);

  // -----------------------------------------------------------------------------
  // Rebuild index (journaled)
  // -----------------------------------------------------------------------------

  /// Rebuilds the entire index from the current box contents.
  ///
  /// This is called automatically if the index is out-of-date or the schema
  /// has changed. [onProgress] is called with a value between 0.0 and 1.0
  /// to report progress.
  Future<void> rebuildIndex({bool bypassInit = true}) async {
    if (!bypassInit) {
      await ensureInitialized();
    }
    await _engine.nativeBox.clear();
    _cache.clear();
    var processed = 0;
    const chunk = 500;
    final buffer = <String, Set<K>>{};
    Future<void> flush() async {
      if (buffer.isEmpty) return;
      final payload = <String, List<K>>{};
      buffer.forEach((token, set) {
        if (set.isNotEmpty) payload[token] = set.toList(growable: false);
      });
      if (payload.isNotEmpty) await _engine.nativeBox.putAll(payload);
      buffer.clear();
    }

    await foreachValue((k, v) async {
      for (final t in _analyze(v)) {
        (buffer[t] ??= <K>{}).add(k);
      }
      processed++;
      if (processed % chunk == 0) {
        await flush();
      }
    });
    await flush();
    await _stampSnapshot();
  }

  // --- Snapshot / signature helpers ------------------------------------------

  /// Computes a simple 32-bit FNV-1a hash for a string.
  ///
  /// Used to store analyzer signatures as ints in the journal.
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

  /// Computes a signature hash for the current analyzer configuration.
  ///
  /// Used to detect schema changes that require index rebuilds.
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

  /// Returns a snapshot of the current box state for index validation.
  ///
  /// Includes file modification time, size, entry count, and analyzer signature.
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

  /// Writes a new snapshot to the journal after index changes.
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

  /// Determines if the index should be rebuilt based on journal and snapshot.
  ///
  /// Returns true if the index is dirty, schema changed, or data changed
  /// out-of-band.
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

  /// Optionally probes the index for consistency before a rebuild.
  ///
  /// If [probes] > 0, checks a sample of items to see if the index is stale.
  /// Returns true if the index appears valid.
  Future<bool> _quickIndexProbe({int probes = 0}) async {
    if (probes <= 0) return true; // skip probe
    final total = await nativeBox.length;
    if (total == 0) return true;

    final step = math.max(1, total ~/ probes);
    for (int i = 0, seen = 0; i < total && seen < probes; i += step, seen++) {
      final k = await nativeBox.keyAt(i);
      if (k == null) continue;
      final v = await nativeBox.get(k);
      if (v == null) continue;
      final tokens = _analyze(v).toSet();
      bool init = false;
      for (final t in tokens.take(8)) {
        if (!init) {
          await _engine.ensureInitialized();
          init = true;
        }

        final keys = await _engine.readToken(t);
        if (!keys.contains(k)) return false; // stale
      }
    }
    return true;
  }

  // -----------------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------------

  /// Iterates over two iterables in parallel, calling [f] with the current elements.
  void _iterateTogether<A, B>(
      Iterator<A> a, Iterator<B> b, void Function(A, B) f) {
    while (a.moveNext() && b.moveNext()) {
      f(a.current, b.current);
    }
  }

  /// Analyzes a value [v] into its set of tokens using the configured analyzer.
  Iterable<String> _analyze(T v) => _engine.analyzer.analyze(v);

  /// Invalidates cached tokens for a given [value].
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
      name == other.name;

  @override
  int get hashCode =>
      _engine.hashCode ^ _journal.hashCode ^ _cache.hashCode ^ super.hashCode;

  @override
  String toString() =>
      '${super.toString()} <[ engine: $_engine, journal: $_journal, cache: $_cache ]>';
}
