part of 'indexed.dart';

typedef Loader<T, K> = Future<T?> Function(K key);

class IndexSearcher<K, T> {
  final IndexEngine<K, T> engine;
  final TextAnalyzer<T> analyzer;
  final bool matchAllTokens;
  final bool verifyMatches;
  final int Function(K a, K b)? keyComparator;
  final TokenCache<K> cache;

  IndexSearcher({
    required this.engine,
    required this.analyzer,
    required this.matchAllTokens,
    required this.verifyMatches,
    required this.cache,
    this.keyComparator,
  });

  Future<void> ensureReady() => engine.ensureReady();

  /// Key-only search with ordering + pagination.
  Future<List<K>> searchKeys(
    String query, {
    int? limit,
    int offset = 0,
  }) async {
    final tokens = IndexEngine.normalize(query);
    if (tokens.isEmpty) return const [];

    // gather candidates per token with cache
    final sets = <Set<K>>[];
    for (final t in tokens) {
      final keys = await _tokenKeys(t);
      sets.add(keys.toSet());
    }

    // merge
    Set<K> merged;
    if (matchAllTokens) {
      merged = sets.isEmpty ? <K>{} : sets.reduce((a, b) => a.intersection(b));
    } else {
      merged = <K>{};
      for (final s in sets) {
        merged.addAll(s);
      }
    }

    // stable order
    final list = merged.toList(growable: false);
    _sortInPlace(list);

    // pagination
    if (offset >= list.length) return const [];
    final start = offset.clamp(0, list.length);
    final end =
        (limit == null) ? list.length : (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  /// Value search (loads values via [load]), with optional final verification.
  Future<List<T>> searchValues(
    String query, {
    required Loader<T, K> load,
    int? limit,
    int offset = 0,
  }) async {
    final keys = await searchKeys(query, limit: limit, offset: offset);
    if (!verifyMatches) {
      // fast path, just load
      final out = <T>[];
      for (final k in keys) {
        final v = await load(k);
        if (v != null) out.add(v);
      }
      return out;
    }

    // verify against analyzer tokens (guards stale index)
    final qTokens = IndexEngine.normalize(query);
    final out = <T>[];
    for (final k in keys) {
      final v = await load(k);
      if (v == null) continue;
      final vTokens = analyzer.analyze(v).toSet();
      final ok = matchAllTokens
          ? qTokens.every(vTokens.contains)
          : qTokens.any(vTokens.contains);
      if (ok) out.add(v);
    }
    return out;
  }

  /// Invalidate cache entries impacted by [value] tokens.
  void invalidateFor(T value) {
    cache.invalidateTokens(analyzer.analyze(value));
  }

  void clearCache() => cache.clear();

  // ---- internals ----
  Future<List<K>> _tokenKeys(String token) async {
    final hit = cache.get(token);
    if (hit != null) return hit;
    final fresh = await engine.readToken(token); // single-token fast path
    cache.put(token, fresh);
    return fresh;
  }

  void _sortInPlace(List<K> list) {
    if (keyComparator != null) {
      list.sort(keyComparator);
    } else if (list.isNotEmpty && list.first is Comparable) {
      (list as List<Comparable>).sort();
    } else {
      list.sort((a, b) => a.toString().compareTo(b.toString()));
    }
  }
}
