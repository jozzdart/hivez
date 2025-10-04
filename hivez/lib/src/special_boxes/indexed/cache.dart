part of 'indexed.dart';

abstract class TokenKeyCache<K> {
  Future<List<K>> get(String token, Future<List<K>> Function() loader);
  void invalidateTokens(Iterable<String> tokens);
  void clear();
}

/// No caching (use when capacity == 0).
class NoopTokenKeyCache<K> implements TokenKeyCache<K> {
  const NoopTokenKeyCache();
  @override
  Future<List<K>> get(String token, Future<List<K>> Function() loader) =>
      loader();
  @override
  void invalidateTokens(Iterable<String> tokens) {}
  @override
  void clear() {}
}

/// Simple LRU using LinkedHashMap insertion order.
class LruTokenKeyCache<K> implements TokenKeyCache<K> {
  final int capacity;
  final _map = <String, List<K>>{};

  LruTokenKeyCache(this.capacity) : assert(capacity > 0);

  @override
  Future<List<K>> get(String token, Future<List<K>> Function() loader) async {
    // Fast path: hit
    final hit = _map.remove(token);
    if (hit != null) {
      // refresh LRU position
      _map[token] = hit;
      return hit;
    }
    // Miss: load and store
    final fresh = List<K>.unmodifiable(await loader());
    _map[token] = fresh;
    // Evict if needed
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
