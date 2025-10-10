part of 'indexed.dart';

/// {@template index_searcher}
/// Provides a high-level, production-grade search pipeline for full-text queries
/// over an [IndexedBox]. The [IndexSearcher] is responsible for translating
/// user queries into token sets, retrieving postings (key sets) from the index,
/// merging and ordering results, and optionally verifying values to guard
/// against stale or out-of-date index entries.
///
/// The search pipeline consists of the following stages:
/// 1. **Tokenization:** The query string is normalized and split into tokens.
/// 2. **Postings Retrieval:** For each token, the set of matching keys is
///    retrieved from the index, using a cache for efficiency.
/// 3. **Merging:** The sets of keys are merged using either intersection (AND)
///    or union (OR), depending on the index configuration.
/// 4. **Ordering:** The merged keys are ordered using a stable sort, either by
///    a custom comparator, by [Comparable], or by string representation.
/// 5. **Pagination:** The ordered results are paginated using [limit] and [offset].
/// 6. **Verification (optional):** If enabled, values are re-analyzed to ensure
///    they still match the query, protecting against stale index entries.
///
/// This class is designed for use in production systems, with robust error
/// handling, efficient caching, and support for custom ordering and value
/// verification strategies.
///
/// Example usage:
/// ```dart
/// final searcher = IndexSearcher<String, MyModel>(
///   engine: myIndexEngine,
///   cache: myTokenKeyCache,
///   analyzer: myTextAnalyzer,
///   verifyMatches: true,
///   ensureReady: () => myBox.ensureInitialized(),
///   getValue: (key) => myBox.get(key),
/// );
///
/// final keys = await searcher.keys('hello world', limit: 10);
/// final values = await searcher.values('foo bar', offset: 5);
/// await for (final value in searcher.valuesStream('baz')) {
///   print(value);
/// }
/// ```
/// {@endtemplate}
class IndexSearcher<K, T> {
  /// The underlying index engine responsible for token-to-key mappings.
  final IndexEngine<K, T> _engine;

  /// A cache for token-to-key lookups, improving search performance.
  final TokenKeyCache<K> _cache;

  /// The analyzer used to tokenize and normalize values for verification.
  final TextAnalyzer<T> _analyzer;

  /// Whether to verify that returned values still match the query tokens.
  ///
  /// If true, values are re-analyzed and checked against the query tokens,
  /// protecting against stale or out-of-date index entries.
  final bool _verifyMatches;

  /// Optional comparator for ordering keys in search results.
  ///
  /// If not provided, keys are ordered using [Comparable] or their string
  /// representation.
  final int Function(K a, K b)? _keyComparator;

  /// Called before any search to ensure all underlying boxes and resources
  /// are initialized and ready.
  final Future<void> Function() _ensureReady;

  /// Retrieves a value by key from the underlying box.
  ///
  /// This is typically provided by the decorated box or storage layer.
  final Future<T?> Function(K key) _getValue;

  /// Creates a new [IndexSearcher] with the given dependencies.
  ///
  /// - [engine]: The index engine for token-to-key lookups.
  /// - [cache]: A cache for token postings.
  /// - [analyzer]: The analyzer for value verification.
  /// - [verifyMatches]: Whether to verify values against the query.
  /// - [ensureReady]: Callback to ensure all resources are initialized.
  /// - [getValue]: Function to retrieve a value by key.
  /// - [keyComparator]: Optional comparator for ordering keys.
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

  /// Searches for keys matching the given [query] string.
  ///
  /// The search is performed using the configured pipeline:
  /// - Tokenizes the query.
  /// - Retrieves and merges postings for each token.
  /// - Orders the results.
  /// - Applies pagination using [limit] and [offset].
  ///
  /// Returns a list of matching keys, or an empty list if no matches are found.
  ///
  /// Throws if the underlying box or index is not ready.
  Future<List<K>> keys(String query, {int? limit, int offset = 0}) async {
    await _ensureReady();

    final tokens = TextAnalyzer.normalize(query);
    if (tokens.isEmpty) return const [];

    // Gather candidate postings per token (cached).
    final tokenSets = <Set<K>>[];
    for (final t in tokens) {
      final ks = await _cache.get(t, () => _engine.readToken(t));
      tokenSets.add(ks.toSet());
    }

    // Merge by AND/OR depending on engine configuration.
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

    // Order results.
    final list = merged.toList(growable: false);
    _sortStable(list);

    // Paginate results.
    if (offset >= list.length) return const [];
    final start = offset.clamp(0, list.length);
    final end =
        (limit == null) ? list.length : (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  /// Searches for values matching the given [query] string.
  ///
  /// This method:
  /// - Retrieves matching keys using [keys].
  /// - Fetches values for each key.
  /// - Optionally verifies that each value still matches the query tokens,
  ///   using the configured [TextAnalyzer].
  ///
  /// Returns a list of matching values, or an empty list if no matches are found.
  ///
  /// Throws if the underlying box or index is not ready.
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

  /// Returns a stream of keys matching the given [query] string.
  ///
  /// This is a convenience wrapper around [keys], yielding each key in order.
  ///
  /// Example:
  /// ```dart
  /// await for (final key in searcher.keysStream('foo')) {
  ///   print(key);
  /// }
  /// ```
  Stream<K> keysStream(String query) async* {
    final ks = await keys(query);
    for (final k in ks) {
      yield k;
    }
  }

  /// Returns a stream of values matching the given [query] string.
  ///
  /// This is a convenience wrapper around [values], yielding each value in order.
  /// Values are optionally verified against the query tokens.
  ///
  /// Example:
  /// ```dart
  /// await for (final value in searcher.valuesStream('bar')) {
  ///   print(value);
  /// }
  /// ```
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

  /// Verifies that a [value] matches the [query] tokens using the configured analyzer.
  ///
  /// This is used to guard against stale or out-of-date index entries.
  /// Returns `true` if the value matches the query, `false` otherwise.
  bool _verify(String query, T value) {
    final qTokens = TextAnalyzer.normalize(query);
    if (qTokens.isEmpty) return true;
    final vTokens = _analyzer.analyze(value).toSet();
    return _engine.matchAllTokens
        ? qTokens.every(vTokens.contains)
        : qTokens.any(vTokens.contains);
  }

  /// Orders the list of keys using the configured comparator, [Comparable], or string order.
  ///
  /// This ensures stable, predictable ordering of search results.
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
