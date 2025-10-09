part of 'indexed.dart';

/// The core engine for maintaining and updating the full-text token index
/// for an [IndexedBox]. This class is responsible for mapping search tokens
/// to lists of keys, and efficiently updating the index in response to
/// put/delete operations on the main box.
///
/// Type parameters:
/// - [K]: The key type of the indexed box.
/// - [T]: The value type of the indexed box.
class IndexEngine<K, T> extends Box<String, List<K>> {
  /// The [TextAnalyzer] used to extract and tokenize searchable text from values.
  final TextAnalyzer<T> analyzer;

  /// If true, search results must match all tokens (AND semantics).
  /// If false, results may match any token (OR semantics).
  final bool matchAllTokens;

  /// Creates an [IndexEngine] for a given index box.
  ///
  /// - [name]: The name of the underlying Hive box.
  /// - [analyzer]: The text analyzer to use for tokenization.
  /// - [matchAllTokens]: If true, search requires all tokens to match (AND).
  ///   If false, any token match is sufficient (OR).
  /// - Other parameters are forwarded to the base [Box] constructor.
  IndexEngine(
    super.name, {
    super.type,
    super.encryptionCipher,
    super.crashRecovery,
    super.path,
    super.collection,
    super.logger,
    required this.analyzer,
    this.matchAllTokens = true,
  });

  /// Updates the index in response to a put operation on the main box.
  ///
  /// - [key]: The key being inserted/updated.
  /// - [newValue]: The new value being stored.
  /// - [oldValue]: The previous value, if any (for update).
  ///
  /// Removes the key from all tokens associated with [oldValue] (if present),
  /// then adds the key to all tokens for [newValue].
  Future<void> onPut(K key, T newValue, {T? oldValue}) async {
    if (oldValue != null) await _removeKeyFromTokens(key, oldValue);
    await _addKeyToTokens(key, newValue);
  }

  /// Updates the index in response to a delete operation on the main box.
  ///
  /// - [key]: The key being deleted.
  /// - [oldValue]: The value being deleted (required for token removal).
  ///
  /// Removes the key from all tokens associated with [oldValue].
  Future<void> onDelete(K key, {T? oldValue}) async {
    if (oldValue != null) await _removeKeyFromTokens(key, oldValue);
  }

  /// Efficiently updates the index for a batch of put operations.
  ///
  /// - [news]: The new key-value pairs being inserted/updated.
  /// - [olds]: The previous values for the same keys, if any.
  ///
  /// Plans all removals and additions in memory, then applies them in batches.
  Future<void> onPutMany(Map<K, T> news, {Map<K, T>? olds}) async {
    // Plan removals and additions in-memory, apply with batched putAll().
    final removals = <String, Set<K>>{};
    final additions = <String, Set<K>>{};

    if (olds != null && olds.isNotEmpty) {
      for (final e in olds.entries) {
        for (final token in analyzer.analyze(e.value)) {
          (removals[token] ??= <K>{}).add(e.key);
        }
      }
    }
    if (news.isNotEmpty) {
      for (final e in news.entries) {
        for (final token in analyzer.analyze(e.value)) {
          (additions[token] ??= <K>{}).add(e.key);
        }
      }
    }

    await _applyMutations(additions: additions, removals: removals);
  }

  /// Efficiently updates the index for a batch of delete operations.
  ///
  /// - [olds]: The key-value pairs being deleted.
  ///
  /// Removes all keys from their associated tokens in batches.
  Future<void> onDeleteMany(Map<K, T> olds) async {
    final removals = <String, Set<K>>{};
    for (final e in olds.entries) {
      for (final token in analyzer.analyze(e.value)) {
        (removals[token] ??= <K>{}).add(e.key);
      }
    }
    await _applyMutations(removals: removals);
  }

  /// Searches for all keys matching the given [tokens].
  ///
  /// - [tokens]: The list of normalized search tokens.
  ///
  /// Returns a list of keys that match the search criteria.
  /// If [matchAllTokens] is true, only keys present in all token sets are returned (AND).
  /// If false, keys present in any token set are returned (OR).
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

  // ---------------------------------------------------------------------------
  // Internal helpers for index mutation and batching
  // ---------------------------------------------------------------------------

  /// Adds [key] to all tokens generated from [value] in the index.
  ///
  /// Batches updates for efficiency.
  Future<void> _addKeyToTokens(K key, T value) async {
    final payload = <String, List<K>>{};
    for (final token in analyzer.analyze(value)) {
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

  /// Removes [key] from all tokens generated from [value] in the index.
  ///
  /// Batches updates for efficiency. If a token's key list becomes empty,
  /// the token is deleted from the index.
  Future<void> _removeKeyFromTokens(K key, T value) async {
    final payload = <String, List<K>?>{};
    for (final token in analyzer.analyze(value)) {
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

  /// Applies batched additions and removals to the index.
  ///
  /// - [additions]: Map from token to set of keys to add.
  /// - [removals]: Map from token to set of keys to remove.
  ///
  /// For each token, removals are applied before additions.
  /// If a token's key list becomes empty, the token is deleted.
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

  /// Applies a batch of put and delete operations to the index.
  ///
  /// - [payload]: Map from token to new key list (or null to delete).
  ///
  /// Tokens with a null value are deleted from the index.
  /// Tokens with a non-null value are updated via [putAll].
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

  /// Reads the list of keys for a given [token] from the index.
  ///
  /// Returns an empty list if the token is not present.
  Future<List<K>> readToken(String token) async {
    return (await get(token)) ?? <K>[];
  }
}
