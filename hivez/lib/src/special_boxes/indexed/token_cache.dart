part of 'indexed.dart';

class TokenCache<K> {
  final int capacity;
  final _lru = <String, List<K>>{};

  TokenCache({int capacity = 512}) : capacity = capacity.clamp(0, 10000);

  bool get enabled => capacity > 0;

  List<K>? get(String token) {
    if (!enabled) return null;
    final hit = _lru.remove(token);
    if (hit != null) _lru[token] = hit; // refresh LRU position
    return hit;
  }

  void put(String token, List<K> keys) {
    if (!enabled) return;
    if (_lru.containsKey(token)) _lru.remove(token);
    _lru[token] = List<K>.from(keys, growable: false);
    if (_lru.length > capacity) {
      _lru.remove(_lru.keys.first); // evict LRU
    }
  }

  void invalidateTokens(Iterable<String> tokens) {
    if (!enabled) return;
    for (final t in tokens) {
      _lru.remove(t);
    }
  }

  void clear() => _lru.clear();
}
