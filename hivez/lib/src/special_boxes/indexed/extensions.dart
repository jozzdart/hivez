part of 'indexed.dart';

extension CreateIndexedBoxExtensions<K, T> on BoxConfig {
  HivezBoxIndexed<K, T> indexedBox({
    required String Function(T) searchableText,
    TextAnalyzer<T>? analyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) {
    return HivezBoxIndexed<K, T>(
      this,
      analyzer: analyzer,
      searchableText: searchableText,
      matchAllTokens: matchAllTokens,
      tokenCacheCapacity: tokenCacheCapacity,
      verifyMatches: verifyMatches,
      keyComparator: keyComparator,
    );
  }
}

extension CreateIndexedBoxFromType<K, T> on BoxType {
  HivezBoxIndexed<K, T> indexedBox(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
    required String Function(T) searchableText,
    TextAnalyzer<T>? analyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) =>
      HivezBoxIndexed<K, T>(
        boxConfig(
          name,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
        searchableText: searchableText,
        analyzer: analyzer,
        matchAllTokens: matchAllTokens,
        tokenCacheCapacity: tokenCacheCapacity,
        verifyMatches: verifyMatches,
        keyComparator: keyComparator,
      );
}
