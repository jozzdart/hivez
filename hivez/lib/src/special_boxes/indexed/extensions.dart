part of 'indexed.dart';

/// {@template create_indexed_box_from_config}
/// Extension on [BoxConfig] to easily create an [IndexedBox] with full-text search capabilities.
///
/// This extension provides a convenient method to instantiate an [IndexedBox]
/// using the configuration stored in a [BoxConfig] object. It allows you to
/// specify how to extract searchable text from your values, as well as fine-tune
/// the indexing and search behavior.
///
/// Example:
/// ```dart
/// final config = BoxConfig('articles', type: BoxType.regular);
/// final box = config.indexedBox<int, Article>(
///   searchableText: (article) => article.title,
/// );
/// ```
///
/// See also:
/// - [IndexedBox]
/// - [Analyzer]
/// - [TextAnalyzer]
/// {@endtemplate}
extension CreateIndexedBoxFromConfig<K, T> on BoxConfig {
  /// Creates an [IndexedBox] using this [BoxConfig].
  ///
  /// - [searchableText]: A function that extracts the text to be indexed from each value.
  /// - [analyzer]: The [Analyzer] strategy to use for tokenizing text (default: [Analyzer.prefix]).
  /// - [overrideAnalyzer]: Optionally provide a custom [TextAnalyzer] for advanced tokenization.
  /// - [matchAllTokens]: If true, all tokens must match for a result (default: true).
  /// - [tokenCacheCapacity]: Maximum number of tokenized results to cache (default: 512).
  /// - [verifyMatches]: If true, verifies that search results actually match the query (default: false).
  /// - [keyComparator]: Optional comparator for sorting keys in search results.
  ///
  /// Returns a fully configured [IndexedBox] instance.
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

/// {@template create_indexed_box_from_type}
/// Extension on [BoxType] to create an [IndexedBox] with full-text search support.
///
/// This extension allows you to instantiate an [IndexedBox] directly from a [BoxType],
/// specifying all necessary parameters for box creation and indexing behavior.
///
/// Example:
/// ```dart
/// final box = BoxType.lazy.indexedBox<int, Article>(
///   'articles',
///   searchableText: (article) => article.title,
/// );
/// ```
///
/// See also:
/// - [IndexedBox]
/// - [Analyzer]
/// - [TextAnalyzer]
/// {@endtemplate}
extension CreateIndexedBoxFromType<K, T> on BoxType {
  /// Creates an [IndexedBox] of this [BoxType].
  ///
  /// - [name]: The unique name of the box.
  /// - [encryptionCipher]: Optional cipher for encrypting box data.
  /// - [crashRecovery]: Enables crash recovery if true (default: true).
  /// - [path]: Optional custom file system path for box storage.
  /// - [collection]: Optional logical grouping for the box.
  /// - [logger]: Optional logger for box events and diagnostics.
  /// - [searchableText]: Function to extract searchable text from each value.
  /// - [analyzer]: The [Analyzer] strategy for tokenizing text (default: [Analyzer.prefix]).
  /// - [overrideAnalyzer]: Optionally provide a custom [TextAnalyzer].
  /// - [matchAllTokens]: If true, all tokens must match for a result (default: true).
  /// - [tokenCacheCapacity]: Maximum number of tokenized results to cache (default: 512).
  /// - [verifyMatches]: If true, verifies that search results actually match the query (default: false).
  /// - [keyComparator]: Optional comparator for sorting keys in search results.
  ///
  /// Returns a fully configured [IndexedBox] instance.
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
