part of 'indexed.dart';

/// Pure search pipeline: tokens -> postings -> merge -> order -> paginate.
/// Also supports value verification using the analyzer (guards stale index).
class IndexSearcher<K, T> {
  final IndexEngine<K, T> _engine;
  final TokenKeyCache<K> _cache;
  final TextAnalyzer<T> _analyzer;
  final bool _verifyMatches;
  final int Function(K a, K b)? _keyComparator;

  /// Called before any search to ensure all boxes are initialized.
  final Future<void> Function() _ensureReady;

  /// How to get a value by key (provided by the decorated box).
  final Future<T?> Function(K key) _getValue;

  IndexSearcher({
    required IndexEngine<K, T> engine,
    required TokenKeyCache<K> cache,
    required TextAnalyzer<T> analyzer,
    required bool verifyMatches,
    required Future<void> Function() ensureReady,
    required Future<T?> Function(K) getValue,
    int Function(K a, K b)? keyComparator,
  })  : _engine = engine,
        _cache = cache,
        _analyzer = analyzer,
        _verifyMatches = verifyMatches,
        _keyComparator = keyComparator,
        _ensureReady = ensureReady,
        _getValue = getValue;

  Future<List<K>> keys(String query, {int? limit, int offset = 0}) async {
    await _ensureReady();

    final tokens = IndexEngine.normalize(query);
    if (tokens.isEmpty) return const [];

    // Gather candidate postings per token (cached).
    final tokenSets = <Set<K>>[];
    for (final t in tokens) {
      final ks = await _cache.get(t, () => _engine.readToken(t));
      tokenSets.add(ks.toSet());
    }

    // Merge by AND/OR.
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

    // Order.
    final list = merged.toList(growable: false);
    _sortStable(list);

    // Paginate.
    if (offset >= list.length) return const [];
    final start = offset.clamp(0, list.length);
    final end =
        (limit == null) ? list.length : (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  Future<List<T>> values(String query, {int? limit, int offset = 0}) async {
    final ks = await keys(query, limit: limit, offset: offset);
    if (ks.isEmpty) return const [];
    final out = <T>[];
    for (final k in ks) {
      final v = await _getValue(k);
      if (v == null) continue;
      if (_verifyMatches && !_verify(query, v)) continue;
      out.add(v);
    }
    return out;
  }

  Stream<K> keysStream(String query) async* {
    final ks = await keys(query);
    for (final k in ks) {
      yield k;
    }
  }

  Stream<T> valuesStream(String query) async* {
    final ks = await keys(query);
    for (final k in ks) {
      final v = await _getValue(k);
      if (v == null) continue;
      if (_verifyMatches && !_verify(query, v)) continue;
      yield v;
    }
  }

  // --- helpers ---------------------------------------------------------------

  bool _verify(String query, T value) {
    final qTokens = IndexEngine.normalize(query);
    if (qTokens.isEmpty) return true;
    final vTokens = _analyzer.analyze(value).toSet();
    return _engine.matchAllTokens
        ? qTokens.every(vTokens.contains)
        : qTokens.any(vTokens.contains);
  }

  void _sortStable(List<K> list) {
    if (list.length < 2) return;
    if (_keyComparator != null) {
      list.sort(_keyComparator);
      return;
    }
    final first = list.first;
    if (first is Comparable) {
      // Sort using Comparable if available.
      (list as List).sort();
    } else {
      list.sort((a, b) => a.toString().compareTo(b.toString()));
    }
  }
}
