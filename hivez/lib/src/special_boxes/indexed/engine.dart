part of 'indexed.dart';

class IndexEngine<K, T> extends ConfiguredBox<String, List<K>> {
  final TextAnalyzer<T> analyzer;
  final bool matchAllTokens;

  IndexEngine(
    super.config, {
    required this.analyzer,
    this.matchAllTokens = false,
  });

  Future<void> onPut(K key, T newValue, {T? oldValue}) async {
    if (oldValue != null) await _removeKeyFromTokens(key, oldValue);
    await _addKeyToTokens(key, newValue);
  }

  Future<void> onDelete(K key, {T? oldValue}) async {
    if (oldValue != null) await _removeKeyFromTokens(key, oldValue);
  }

  Future<void> onPutMany(Map<K, T> news, {Map<K, T>? olds}) async {
    // Plan removals and additions in-memory, apply with batched putAll().
    final removals = <String, Set<K>>{};
    final additions = <String, Set<K>>{};

    if (olds != null && olds.isNotEmpty) {
      for (final e in olds.entries) {
        for (final token in analyzer.analyze(e.value).toSet()) {
          (removals[token] ??= <K>{}).add(e.key);
        }
      }
    }
    if (news.isNotEmpty) {
      for (final e in news.entries) {
        for (final token in analyzer.analyze(e.value).toSet()) {
          (additions[token] ??= <K>{}).add(e.key);
        }
      }
    }

    await _applyMutations(additions: additions, removals: removals);
  }

  Future<void> onDeleteMany(Map<K, T> olds) async {
    final removals = <String, Set<K>>{};
    for (final e in olds.entries) {
      for (final token in analyzer.analyze(e.value).toSet()) {
        (removals[token] ??= <K>{}).add(e.key);
      }
    }
    await _applyMutations(removals: removals);
  }

  // Search keys for tokens, merged by AND/OR.
  Future<List<K>> searchKeys(List<String> tokens) async {
    if (tokens.isEmpty) return const [];
    final tokenSets = <Set<K>>[];
    for (final t in tokens) {
      final ks = await get(t) ?? <K>[];
      tokenSets.add(ks.toSet());
    }
    if (tokenSets.isEmpty) return const [];
    final merged = matchAllTokens
        ? tokenSets.reduce((a, b) => a.intersection(b))
        : tokenSets.fold(<K>{}, (acc, s) => acc..addAll(s));
    return merged.toList(growable: false);
  }

  // Internals ------------------------------------------------------------------

  Future<void> _addKeyToTokens(K key, T value) async {
    final payload = <String, List<K>>{};
    for (final token in analyzer.analyze(value).toSet()) {
      final existing = await get(token) ?? <K>[];
      if (!existing.contains(key)) {
        payload[token] = List<K>.from(existing)..add(key);
        if (payload.length >= 256) {
          await putAll(payload);
          payload.clear();
        }
      }
    }
    if (payload.isNotEmpty) await putAll(payload);
  }

  Future<void> _removeKeyFromTokens(K key, T value) async {
    final payload = <String, List<K>?>{};
    for (final token in analyzer.analyze(value).toSet()) {
      final existing = await get(token);
      if (existing == null) continue;
      final next = List<K>.from(existing)..remove(key);
      payload[token] = next.isEmpty ? null : next;
      if (payload.length >= 256) {
        await _putAllOrDeleteAll(payload);
        payload.clear();
      }
    }
    if (payload.isNotEmpty) await _putAllOrDeleteAll(payload);
  }

  Future<void> _applyMutations({
    Map<String, Set<K>>? additions,
    Map<String, Set<K>>? removals,
  }) async {
    final tokens = <String>{};
    if (additions != null) tokens.addAll(additions.keys);
    if (removals != null) tokens.addAll(removals.keys);

    final payload = <String, List<K>?>{};
    for (final token in tokens) {
      var set = (await get(token))?.toSet() ?? <K>{};

      // IMPORTANT: removals first, then additions
      if (removals != null && removals.containsKey(token)) {
        set.removeAll(removals[token]!);
      }
      if (additions != null && additions.containsKey(token)) {
        set.addAll(additions[token]!);
      }

      payload[token] = set.isEmpty ? null : set.toList(growable: false);

      if (payload.length >= 256) {
        await _putAllOrDeleteAll(payload);
        payload.clear();
      }
    }

    if (payload.isNotEmpty) await _putAllOrDeleteAll(payload);
  }

  Future<void> _putAllOrDeleteAll(Map<String, List<K>?> payload) async {
    final puts = <String, List<K>>{};
    final dels = <String>[];
    payload.forEach((token, list) {
      if (list == null) {
        dels.add(token);
      } else {
        puts[token] = list;
      }
    });
    if (dels.isNotEmpty) {
      // No batch delete API; delete one-by-one is fine (usually small).
      for (final t in dels) {
        await delete(t);
      }
    }
    if (puts.isNotEmpty) {
      await putAll(puts);
    }
  }

  // engine.dart (add this helper)
  Future<List<K>> readToken(String token) async {
    return (await get(token)) ?? <K>[];
  }
}
