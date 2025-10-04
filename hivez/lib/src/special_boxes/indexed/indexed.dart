import 'dart:collection';

import 'package:hivez/src/builders/builders.dart';
import 'package:synchronized/synchronized.dart';

part 'engine.dart';

class HivezBoxIndexed<K, T> extends ConfiguredBox<K, T> {
  // Engine and meta
  final IndexEngine<K, T> _engine;
  final ConfiguredBox<String, int> _meta; // '__dirty' flag: 1/0

  // Concurrency (single-isolate)
  final Lock _writeLock = Lock();

  // Tunables
  final int _tokenCacheCapacity;
  final bool _verifyMatches;
  final int Function(K a, K b)? _keyComparator;

  // LRU token cache: token -> keys
  final LinkedHashMap<String, List<K>> _tokenCache = LinkedHashMap();

  HivezBoxIndexed(
    super.config, {
    required String Function(T) searchableText,
    bool matchAllTokens = false,
    int tokenCacheCapacity = 512,
    bool verifyMatches = true,
    int Function(K a, K b)? keyComparator,
    // Optional: provide your own analyzer
    TextAnalyzer<T>? analyzer,
    // Optional: choose index box type
    BoxType? indexType,
    BoxType? metaType,
  })  : _tokenCacheCapacity = tokenCacheCapacity.clamp(0, 10000),
        _verifyMatches = verifyMatches,
        _keyComparator = keyComparator,
        _engine = IndexEngine<K, T>(
          analyzer: analyzer ?? BasicTextAnalyzer<T>(searchableText),
          storage: config
              .copyWith(
                name: '${config.name}__idx',
                type: indexType ?? BoxType.lazy,
              )
              .createConfiguredBox<String, List<K>>(),
          matchAllTokens: matchAllTokens,
        ),
        _meta = config
            .copyWith(
              name: '${config.name}__idx_meta',
              type: metaType ?? BoxType.regular,
            )
            .createConfiguredBox<String, int>();

  // Lifecycle ------------------------------------------------------------------

  @override
  Future<void> ensureInitialized() async {
    await super.ensureInitialized(); // main box
    await _engine.ensureReady(); // index box
    await _meta.ensureInitialized(); // meta box

    // If we crashed mid-write previously, rebuild deterministically.
    if (await _isDirty()) {
      _log('[Indexed:${config.name}] Dirty flag detected → rebuilding index…');
      await rebuildIndex();
    }
  }

// -----------------------------------------------------------------------------
// Disk / Close / Flush / Compact
// -----------------------------------------------------------------------------
  @override
  Future<void> flushBox() async {
    // No dirty toggle: flush is non-mutating
    await _writeLock.synchronized(() async {
      // Best-effort flush of all siblings too
      try {
        await _engine.storage.flushBox();
      } catch (_) {}
      try {
        await _meta.flushBox();
      } catch (_) {}
      await super.flushBox();
    });
  }

  @override
  Future<void> compactBox() async {
    // No dirty toggle: compaction is non-mutating at the logical level
    await _writeLock.synchronized(() async {
      try {
        await _engine.storage.compactBox();
      } catch (_) {}
      try {
        await _meta.compactBox();
      } catch (_) {}
      await super.compactBox();
    });
  }

  @override
  Future<void> closeBox() async {
    // No dirty toggle: close is non-mutating
    await _writeLock.synchronized(() async {
      // Flush everyone first, then close siblings, then main
      try {
        await _engine.storage.flushBox();
      } catch (_) {}
      try {
        await _meta.flushBox();
      } catch (_) {}
      await super.flushBox();

      try {
        await _engine.storage.closeBox();
      } catch (_) {}
      try {
        await _meta.closeBox();
      } catch (_) {}
      _tokenCache.clear();
      await super.closeBox();
    });
  }

  @override
  Future<void> deleteFromDisk() async {
    // No dirty toggle here; we’re tearing everything down
    await _writeLock.synchronized(() async {
      _tokenCache.clear();

      // Delete siblings first so a crash can’t leave orphans
      try {
        await _engine.storage.deleteFromDisk();
      } catch (_) {}
      try {
        await _meta.deleteFromDisk();
      } catch (_) {}

      // Finally delete the main data box
      await super.deleteFromDisk();
    });
  }

  /// Clears runtime caches + resets dirty flag without wiping persistent data.
  Future<void> resetRuntimeState() async {
    await _writeLock.synchronized(() async {
      _log('[Indexed:${config.name}] Resetting runtime state...');
      _tokenCache.clear();
      await _markClean();
    });
  }

  // Write path -----------------------------------------------------------------

  @override
  Future<void> put(K key, T value) async {
    await _writeLock.synchronized(() async {
      await _markDirty();
      final old = await super.get(key);
      await super.put(key, value);
      await _engine.onPut(key, value, oldValue: old);
      _invalidateTokensFor(old);
      _invalidateTokensFor(value);
      await _markClean();
    });
  }

  @override
  Future<void> putAll(Map<K, T> entries) async {
    if (entries.isEmpty) return;
    await _writeLock.synchronized(() async {
      await _markDirty();

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

      await _markClean();
    });
  }

  @override
  Future<int> add(T value) async {
    return _writeLock.synchronized(() async {
      await _markDirty();
      final id = await super.add(value);
      await _engine.onPut(id as K, value);
      _invalidateTokensFor(value);
      await _markClean();
      return id;
    });
  }

  @override
  Future<void> addAll(Iterable<T> values) async {
    if (values.isEmpty) return;
    await _writeLock.synchronized(() async {
      await _markDirty();
      final news = <K, T>{};
      for (final v in values) {
        final id = await super.add(v);
        news[id as K] = v;
        _invalidateTokensFor(v);
      }
      await _engine.onPutMany(news);
      await _markClean();
    });
  }

  @override
  Future<void> delete(K key) async {
    await _writeLock.synchronized(() async {
      await _markDirty();
      final old = await super.get(key);
      await super.delete(key);
      if (old != null) {
        await _engine.onDelete(key, oldValue: old);
        _invalidateTokensFor(old);
      }
      await _markClean();
    });
  }

  @override
  Future<void> deleteAll(Iterable<K> keys) async {
    final unique = keys is Set<K> ? keys : keys.toSet();
    if (unique.isEmpty) return;

    await _writeLock.synchronized(() async {
      await _markDirty();

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

      await _markClean();
    });
  }

  @override
  Future<void> clear() async {
    await _writeLock.synchronized(() async {
      await _markDirty();
      await super.clear();
      await _engine.onClear();
      _tokenCache.clear();
      await _markClean();
    });
  }

  @override
  Future<void> putAt(int index, T value) async {
    await _writeLock.synchronized(() async {
      await _markDirty();
      final k = await super.keyAt(index);
      final old = await super.get(k);
      await super.putAt(index, value);
      await _engine.onPut(k, value, oldValue: old);
      _invalidateTokensFor(old);
      _invalidateTokensFor(value);
      await _markClean();
    });
  }

  @override
  Future<bool> moveKey(K oldKey, K newKey) async {
    return _writeLock.synchronized(() async {
      await _markDirty();
      final v = await super.get(oldKey);
      if (v == null) {
        await _markClean();
        return false;
      }
      final moved = await super.moveKey(oldKey, newKey);
      if (moved) {
        await _engine.onDelete(oldKey, oldValue: v);
        await _engine.onPut(newKey, v);
        _invalidateTokensFor(v);
      }
      await _markClean();
      return moved;
    });
  }

  // Search API -----------------------------------------------------------------

  /// Returns matching values with optional pagination and stable ordering.
  Future<List<T>> search(
    String query, {
    int? limit,
    int offset = 0,
  }) async {
    final keys = await searchKeys(query, limit: limit, offset: offset);
    final out = <T>[];
    for (final k in keys) {
      final v = await super.get(k);
      if (v == null) continue;
      if (_verifyMatches && !_isVerified(query, v)) continue;
      out.add(v);
    }
    return out;
  }

  /// Returns matching keys with optional pagination and stable ordering.
  Future<List<K>> searchKeys(
    String query, {
    int? limit,
    int offset = 0,
  }) async {
    await ensureInitialized();

    final tokens = _normalizeQuery(query);
    if (tokens.isEmpty) return const [];

    // 1) Gather candidate key sets per token with LRU caching.
    final tokenSets = <Set<K>>[];
    for (final t in tokens) {
      final keys = await _getTokenKeysCached(t);
      tokenSets.add(keys.toSet());
    }

    // 2) Merge per AND/OR semantics.
    Set<K> merged;
    if (_engine.matchAllTokens) {
      merged = tokenSets.isEmpty
          ? <K>{}
          : tokenSets.reduce((a, b) => a.intersection(b));
    } else {
      merged = <K>{};
      for (final s in tokenSets) {
        merged.addAll(s);
      }
    }

    // 3) Stable ordering.
    final list = merged.toList(growable: false);
    if (_keyComparator != null) {
      list.sort(_keyComparator);
    } else if (list.isNotEmpty && list.first is Comparable) {
      (list as List<Comparable>).sort();
    } else {
      list.sort((a, b) => a.toString().compareTo(b.toString()));
    }

    // 4) Pagination.
    if (offset >= list.length) return const [];
    final start = offset.clamp(0, list.length);
    final end =
        (limit == null) ? list.length : (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  /// Streaming variant: emits keys progressively.
  Stream<K> searchKeysStream(String query) async* {
    final keys = await searchKeys(query);
    for (final k in keys) {
      yield k;
    }
  }

  /// Streaming variant: emits values progressively (with optional verify).
  Stream<T> searchStream(String query) async* {
    final keys = await searchKeys(query);
    for (final k in keys) {
      final v = await super.get(k);
      if (v == null) continue;
      if (_verifyMatches && !_isVerified(query, v)) continue;
      yield v;
    }
  }

  /// Rebuilds the entire index from current box content (chunked & crash-safe).
  Future<void> rebuildIndex(
      {void Function(double progress)? onProgress}) async {
    await ensureInitialized();
    await _markDirty();

    // Clear index first
    await _engine.onClear();
    _tokenCache.clear();

    final total = await length;
    var processed = 0;
    const chunk = 500;

    // Build token -> Set<key> buffer to minimize duplicates, then flush as List.
    final buffer = <String, Set<K>>{};

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      final payload = <String, List<K>>{};
      buffer.forEach((token, set) {
        if (set.isEmpty) return;
        payload[token] = set.toList(growable: false);
      });
      if (payload.isNotEmpty) {
        await _engine.storage.putAll(payload);
      }
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
        // Yield back to event loop to keep UI responsive.
        await Future<void>.delayed(Duration.zero);
      }
    });

    await flush();
    onProgress?.call(1.0);
    await _markClean();
  }

  // Helpers --------------------------------------------------------------------

  Future<void> _markDirty() async => _meta.put('__dirty', 1);
  Future<void> _markClean() async => _meta.put('__dirty', 0);
  Future<bool> _isDirty() async => (await _meta.get('__dirty')) == 1;

  List<String> _analyze(T v) => _engine.analyzer.analyze(v);

  // Token cache with simple LRU discipline.
  Future<List<K>> _getTokenKeysCached(String token) async {
    if (_tokenCacheCapacity <= 0) {
      return await _engine.storage.get(token) ?? <K>[];
    }
    final cached = _tokenCache.remove(token);
    if (cached != null) {
      _tokenCache[token] = cached; // refresh LRU position
      return cached;
    }
    final fresh = await _engine.storage.get(token) ?? <K>[];
    _cachePut(token, fresh);
    return fresh;
  }

  void _cachePut(String token, List<K> keys) {
    if (_tokenCacheCapacity <= 0) return;
    if (_tokenCache.containsKey(token)) _tokenCache.remove(token);
    _tokenCache[token] = List<K>.from(keys, growable: false);
    if (_tokenCache.length > _tokenCacheCapacity) {
      _tokenCache.remove(_tokenCache.keys.first); // evict LRU
    }
  }

  void _invalidateTokensFor(T? value) {
    if (value == null || _tokenCacheCapacity <= 0) return;
    for (final t in _analyze(value)) {
      _tokenCache.remove(t);
    }
  }

  bool _isVerified(String query, T value) {
    final qTokens = _normalizeQuery(query);
    if (qTokens.isEmpty) return true;
    final vTokens = _analyze(value).toSet();
    return _engine.matchAllTokens
        ? qTokens.every(vTokens.contains)
        : qTokens.any(vTokens.contains);
  }

  List<String> _normalizeQuery(String q) => IndexEngine.normalize(q);

  void _log(String msg) {
    try {
      config.logger?.call(msg);
      // ignore if no logger
    } catch (_) {}
  }
}
