import 'dart:collection';

import 'package:hivez/src/builders/builders.dart';
import 'package:synchronized/synchronized.dart';

part 'engine.dart';
part 'journal.dart';
part 'token_cache.dart';
part 'index_searcher.dart';

class HivezBoxIndexed<K, T> extends ConfiguredBox<K, T> {
  // Engine and journal
  final IndexEngine<K, T> _engine;
  final IndexJournal _journal;

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
  })  : _tokenCacheCapacity = tokenCacheCapacity.clamp(0, 10000),
        _verifyMatches = verifyMatches,
        _keyComparator = keyComparator,
        _engine = IndexEngine<K, T>(
          analyzer: analyzer ?? BasicTextAnalyzer<T>(searchableText),
          storage: config
              .copyWith(
                name: '${config.name}__idx',
              )
              .createConfiguredBox<String, List<K>>(),
          matchAllTokens: matchAllTokens,
        ),
        _journal = BoxIndexJournal(
          config.copyWith(
            name: '${config.name}__idx_meta',
          ),
        );

  // Small helper so every write uses the same discipline.
  Future<R> _writeTxn<R>(Future<R> Function() body) =>
      _writeLock.synchronized(() => _journal.runWrite(body));

  // -----------------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------------
  @override
  Future<void> ensureInitialized() async {
    await super.ensureInitialized(); // main box
    await _engine.ensureReady(); // index box
    await _journal.ensureInitialized(); // meta/journal

    if (await _journal.isDirty()) {
      _log('[Indexed:${config.name}] Dirty flag detected → rebuilding index…');
      await rebuildIndex();
    }
  }

  // -----------------------------------------------------------------------------
  // Disk / Close / Flush / Compact  (non-mutating; no dirty toggles)
  // -----------------------------------------------------------------------------
  @override
  Future<void> flushBox() async {
    await _writeLock.synchronized(() async {
      try {
        await _engine.storage.flushBox();
      } catch (_) {}
      try {
        await _journal.flushBox();
      } catch (_) {}
      await super.flushBox();
    });
  }

  @override
  Future<void> compactBox() async {
    await _writeLock.synchronized(() async {
      try {
        await _engine.storage.compactBox();
      } catch (_) {}
      try {
        await _journal.compactBox();
      } catch (_) {}
      await super.compactBox();
    });
  }

  @override
  Future<void> closeBox() async {
    await _writeLock.synchronized(() async {
      try {
        await _engine.storage.flushBox();
      } catch (_) {}
      try {
        await _journal.flushBox();
      } catch (_) {}
      await super.flushBox();

      try {
        await _engine.storage.closeBox();
      } catch (_) {}
      try {
        await _journal.closeBox();
      } catch (_) {}
      _tokenCache.clear();
      await super.closeBox();
    });
  }

  @override
  Future<void> deleteFromDisk() async {
    await _writeLock.synchronized(() async {
      _tokenCache.clear();
      try {
        await _engine.storage.deleteFromDisk();
      } catch (_) {}
      try {
        await _journal.deleteFromDisk();
      } catch (_) {}
      await super.deleteFromDisk();
    });
  }

  /// Clears runtime caches + resets journal (no persistent data loss).
  Future<void> resetRuntimeState() async {
    await _writeLock.synchronized(() async {
      _tokenCache.clear();
      await _journal.reset();
    });
  }

  // -----------------------------------------------------------------------------
  // Write path (all wrapped in _writeTxn)
  // -----------------------------------------------------------------------------
  @override
  Future<void> put(K key, T value) => _writeTxn(() async {
        final old = await super.get(key);
        await super.put(key, value);
        await _engine.onPut(key, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
      });

  @override
  Future<void> putAll(Map<K, T> entries) {
    if (entries.isEmpty) return Future.value();
    return _writeTxn(() async {
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
    });
  }

  @override
  Future<int> add(T value) => _writeTxn(() async {
        final id = await super.add(value);
        await _engine.onPut(id as K, value);
        _invalidateTokensFor(value);
        return id;
      });

  @override
  Future<void> addAll(Iterable<T> values) {
    if (values.isEmpty) return Future.value();
    return _writeTxn(() async {
      final news = <K, T>{};
      for (final v in values) {
        final id = await super.add(v);
        news[id as K] = v;
        _invalidateTokensFor(v);
      }
      await _engine.onPutMany(news);
    });
  }

  @override
  Future<void> delete(K key) => _writeTxn(() async {
        final old = await super.get(key);
        await super.delete(key);
        if (old != null) {
          await _engine.onDelete(key, oldValue: old);
          _invalidateTokensFor(old);
        }
      });

  @override
  Future<void> deleteAll(Iterable<K> keys) {
    final unique = keys is Set<K> ? keys : keys.toSet();
    if (unique.isEmpty) return Future.value();
    return _writeTxn(() async {
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
    });
  }

  @override
  Future<void> clear() => _writeTxn(() async {
        await super.clear();
        await _engine.onClear();
        _tokenCache.clear();
      });

  @override
  Future<void> putAt(int index, T value) => _writeTxn(() async {
        final k = await super.keyAt(index);
        final old = await super.get(k);
        await super.putAt(index, value);
        await _engine.onPut(k, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
      });

  @override
  Future<bool> moveKey(K oldKey, K newKey) => _writeTxn(() async {
        final v = await super.get(oldKey);
        if (v == null) return false;
        final moved = await super.moveKey(oldKey, newKey);
        if (moved) {
          await _engine.onDelete(oldKey, oldValue: v);
          await _engine.onPut(newKey, v);
          _invalidateTokensFor(v);
        }
        return moved;
      });

  // -----------------------------------------------------------------------------
  // Search API (unchanged except for helper calls)
  // -----------------------------------------------------------------------------
  Future<List<T>> search(String query, {int? limit, int offset = 0}) async {
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

  Future<List<K>> searchKeys(String query, {int? limit, int offset = 0}) async {
    await ensureInitialized();
    final tokens = _normalizeQuery(query);
    if (tokens.isEmpty) return const [];

    // Gather candidates per token with LRU caching
    final tokenSets = <Set<K>>[];
    for (final t in tokens) {
      final keys = await _getTokenKeysCached(t);
      tokenSets.add(keys.toSet());
    }

    // Merge by AND/OR semantics
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

    // Stable ordering
    final list = merged.toList(growable: false);
    if (_keyComparator != null) {
      list.sort(_keyComparator);
    } else if (list.isNotEmpty && list.first is Comparable) {
      (list as List<Comparable>).sort();
    } else {
      list.sort((a, b) => a.toString().compareTo(b.toString()));
    }

    // Pagination
    if (offset >= list.length) return const [];
    final start = offset.clamp(0, list.length);
    final end =
        (limit == null) ? list.length : (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  // -----------------------------------------------------------------------------
  // Rebuild index (journaled)
  // -----------------------------------------------------------------------------
  Future<void> rebuildIndex({void Function(double progress)? onProgress}) =>
      _writeTxn(() async {
        await _engine.onClear();
        _tokenCache.clear();

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
          if (payload.isNotEmpty) await _engine.storage.putAll(payload);
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
            await Future<void>.delayed(Duration.zero);
          }
        });

        await flush();
        onProgress?.call(1.0);
      });

  // -----------------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------------
  List<String> _analyze(T v) => _engine.analyzer.analyze(v);

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
    } catch (_) {}
  }
}
