part of 'indexed.dart';

/// An abstract cache for mapping search tokens to lists of keys in an [IndexedBox].
///
/// Used to speed up repeated token lookups by avoiding redundant index box reads.
/// Implementations may use different caching strategies (e.g., LRU, no cache).
///
/// Type parameter [K] is the key type of the indexed box.
abstract class TokenKeyCache<K> {
  /// Returns the cached list of keys for [token], or loads and caches them using [loader] if absent.
  ///
  /// - [token]: The search token to look up.
  /// - [loader]: A function that loads the list of keys for [token] if not cached.
  ///
  /// Returns a [Future] that completes with the list of keys for [token].
  Future<List<K>> get(String token, Future<List<K>> Function() loader);

  /// Invalidates (removes) any cached entries for the given [tokens].
  ///
  /// This should be called when the index for these tokens may have changed (e.g., after a put/delete).
  void invalidateTokens(Iterable<String> tokens);

  /// Clears all cached entries.
  void clear();
}

/// A [TokenKeyCache] implementation that performs no caching.
///
/// Used when cache capacity is set to zero. All lookups are delegated to the loader function.
class NoopTokenKeyCache<K> implements TokenKeyCache<K> {
  /// Creates a [NoopTokenKeyCache].
  const NoopTokenKeyCache();

  @override
  Future<List<K>> get(String token, Future<List<K>> Function() loader) =>
      loader();

  @override
  void invalidateTokens(Iterable<String> tokens) {}

  @override
  void clear() {}
}

/// A simple Least Recently Used (LRU) cache for mapping tokens to lists of keys.
///
/// Uses a [LinkedHashMap] to maintain insertion order for LRU eviction.
/// When the cache exceeds [capacity], the least recently used entry is evicted.
///
/// Type parameter [K] is the key type of the indexed box.
class LruTokenKeyCache<K> implements TokenKeyCache<K> {
  /// The maximum number of tokens to cache.
  final int capacity;

  /// Internal map from token to list of keys.
  final _map = <String, List<K>>{};

  /// Creates an LRU cache with the given [capacity].
  ///
  /// Throws [AssertionError] if [capacity] is not greater than zero.
  LruTokenKeyCache(this.capacity) : assert(capacity > 0);

  @override
  Future<List<K>> get(String token, Future<List<K>> Function() loader) async {
    // Fast path: cache hit
    final hit = _map.remove(token);
    if (hit != null) {
      // Move to most recently used position
      _map[token] = hit;
      return hit;
    }
    // Cache miss: load and store
    final fresh = List<K>.unmodifiable(await loader());
    _map[token] = fresh;
    // Evict least recently used if over capacity
    if (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
    return fresh;
  }

  @override
  void invalidateTokens(Iterable<String> tokens) {
    for (final t in tokens) {
      _map.remove(t);
    }
  }

  @override
  void clear() => _map.clear();
}
