part of 'indexed.dart';

extension CreateIndexedBoxFromConfig<K, T> on BoxConfig {
  IndexedBox<K, T> indexedBox({
    required String Function(T) searchableText,
    Analyzer analyzer = Analyzer.prefix,
    TextAnalyzer<T>? overrideAnalyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) {
    return IndexedBox<K, T>(
      name,
      type: type,
      encryptionCipher: encryptionCipher,
      crashRecovery: crashRecovery,
      path: path,
      collection: collection,
      logger: logger,
      analyzer: analyzer,
      overrideAnalyzer: overrideAnalyzer,
      searchableText: searchableText,
      matchAllTokens: matchAllTokens,
      tokenCacheCapacity: tokenCacheCapacity,
      verifyMatches: verifyMatches,
      keyComparator: keyComparator,
    );
  }
}

extension CreateIndexedBoxFromType<K, T> on BoxType {
  IndexedBox<K, T> indexedBox(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
    required String Function(T) searchableText,
    Analyzer analyzer = Analyzer.prefix,
    TextAnalyzer<T>? overrideAnalyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) =>
      IndexedBox<K, T>(
        name,
        type: this,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
        path: path,
        collection: collection,
        logger: logger,
        searchableText: searchableText,
        analyzer: analyzer,
        overrideAnalyzer: overrideAnalyzer,
        matchAllTokens: matchAllTokens,
        tokenCacheCapacity: tokenCacheCapacity,
        verifyMatches: verifyMatches,
        keyComparator: keyComparator,
      );
}
