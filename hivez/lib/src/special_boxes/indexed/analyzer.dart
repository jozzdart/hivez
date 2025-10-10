part of 'indexed.dart';

/// The type of text analyzer to use for tokenizing and indexing values in an [IndexedBox].
///
/// - [basic]: Tokenizes text into normalized words (tokens).
/// - [prefix]: Tokenizes text into all prefixes of each token, for fast prefix search.
/// - [ngram]: Tokenizes text into all n-grams (substrings of length N), for fuzzy/partial search.
enum Analyzer {
  /// Tokenizes text into normalized words (tokens).
  basic,

  /// Tokenizes text into all prefixes of each token, for fast prefix search.
  prefix,

  /// Tokenizes text into all n-grams (substrings of length N), for fuzzy/partial search.
  ngram,
}

/// Extension for creating a [TextAnalyzer] from an [Analyzer] enum value.
///
/// Example:
/// ```dart
/// final analyzer = Analyzer.prefix.analyzer((user) => user.name);
/// ```
extension CreateTextAnalyzerExtensions on Analyzer {
  /// Returns a [TextAnalyzer] for the given [searchableText] extractor.
  ///
  /// The returned analyzer type depends on the enum value:
  /// - [Analyzer.basic]: [TextAnalyzer.basic]
  /// - [Analyzer.prefix]: [TextAnalyzer.prefix]
  /// - [Analyzer.ngram]: [TextAnalyzer.ngram]
  TextAnalyzer<T> analyzer<T>(String Function(T) searchableText) {
    switch (this) {
      case Analyzer.basic:
        return TextAnalyzer.basic(searchableText);
      case Analyzer.prefix:
        return TextAnalyzer.prefix(searchableText);
      case Analyzer.ngram:
        return TextAnalyzer.ngram(searchableText);
    }
  }
}

/// Abstract base class for text analyzers used in [IndexedBox] for tokenization.
///
/// Subclasses implement different tokenization strategies for full-text search.
/// Use [TextAnalyzer.basic], [TextAnalyzer.prefix], or [TextAnalyzer.ngram] to create analyzers.
///
/// Example:
/// ```dart
/// final analyzer = TextAnalyzer.prefix((article) => article.title);
/// ```
abstract class TextAnalyzer<T> {
  /// Const constructor for subclasses.
  const TextAnalyzer();

  /// Returns the set of tokens for the given [value].
  ///
  /// The returned tokens are used for indexing and searching.
  Iterable<String> analyze(T value);

  /// Normalizes a string for tokenization:
  /// - Converts to lowercase.
  /// - Removes all non-letter/number characters (Unicode aware).
  /// - Splits on whitespace.
  /// - Filters out tokens of length <= 1.
  ///
  /// Example:
  /// ```dart
  /// TextAnalyzer.normalize('Hello, World!') // ['hello', 'world']
  /// ```
  static Iterable<String> normalize(String q) => q
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .split(RegExp(r'\s+', unicode: true))
      .where((t) => t.length > 1);

  /// Creates a [BasicTextAnalyzer] for the given [searchableText] extractor.
  ///
  /// Tokenizes text into normalized words.
  static TextAnalyzer<T> basic<T>(String Function(T) searchableText) =>
      BasicTextAnalyzer<T>(searchableText);

  /// Creates a [PrefixTextAnalyzer] for the given [searchableText] extractor.
  ///
  /// Tokenizes text into all prefixes of each token, with optional [minPrefix] and [maxPrefix] length.
  static TextAnalyzer<T> prefix<T>(String Function(T) searchableText,
          {int minPrefix = 2, int maxPrefix = 9}) =>
      PrefixTextAnalyzer<T>(searchableText,
          minPrefix: minPrefix, maxPrefix: maxPrefix);

  /// Creates a [NGramTextAnalyzer] for the given [searchableText] extractor.
  ///
  /// Tokenizes text into all n-grams (substrings) of length [minN] to [maxN].
  static TextAnalyzer<T> ngram<T>(String Function(T) searchableText,
          {int minN = 2, int maxN = 6}) =>
      NGramTextAnalyzer<T>(searchableText, minN: minN, maxN: maxN);
}

/// A [TextAnalyzer] that tokenizes text into normalized words (tokens).
///
/// This is the default analyzer for most use cases. It lowercases, strips punctuation,
/// splits on whitespace, and filters out tokens of length <= 1.
class BasicTextAnalyzer<T> extends TextAnalyzer<T> {
  /// Function to extract the searchable text from a value.
  final String Function(T value) searchableText;

  /// Creates a [BasicTextAnalyzer] with the given [searchableText] extractor.
  const BasicTextAnalyzer(this.searchableText);

  @override
  Iterable<String> analyze(T v) => TextAnalyzer.normalize(searchableText(v));
}

/// A [TextAnalyzer] that tokenizes text into all prefixes of each token.
///
/// For example, the token "hello" with [minPrefix]=2 and [maxPrefix]=4 produces:
/// "he", "hel", "hell".
///
/// Useful for implementing fast prefix search (autocomplete).
class PrefixTextAnalyzer<T> extends TextAnalyzer<T> {
  /// Function to extract the searchable text from a value.
  final String Function(T) searchableText;

  /// Minimum prefix length to generate (inclusive).
  final int minPrefix;

  /// Maximum prefix length to generate (inclusive).
  final int maxPrefix;

  /// Creates a [PrefixTextAnalyzer] with the given [searchableText] extractor and prefix bounds.
  const PrefixTextAnalyzer(
    this.searchableText, {
    this.minPrefix = 2,
    this.maxPrefix = 9,
  });

  @override
  Iterable<String> analyze(T v) {
    final tokens = TextAnalyzer.normalize(searchableText(v));
    final result = <String>[];
    for (final t in tokens) {
      final limit = t.length.clamp(minPrefix, maxPrefix);
      for (int i = minPrefix; i <= limit; i++) {
        result.add(t.substring(0, i));
      }
    }
    return result;
  }
}

/// A [TextAnalyzer] that tokenizes text into all n-grams (substrings) of each token.
///
/// For example, the token "hello" with [minN]=2 and [maxN]=3 produces:
/// "he", "el", "ll", "lo", "hel", "ell", "llo".
///
/// Useful for fuzzy/partial search and typo tolerance.
class NGramTextAnalyzer<T> extends TextAnalyzer<T> {
  /// Function to extract the searchable text from a value.
  final String Function(T) searchableText;

  /// Minimum n-gram length to generate (inclusive).
  final int minN;

  /// Maximum n-gram length to generate (inclusive).
  final int maxN;

  /// Creates a [NGramTextAnalyzer] with the given [searchableText] extractor and n-gram bounds.
  const NGramTextAnalyzer(this.searchableText, {this.minN = 2, this.maxN = 6});

  @override
  Iterable<String> analyze(T v) {
    final base = TextAnalyzer.normalize(searchableText(v));
    final out = <String>[];
    for (final token in base) {
      for (int n = minN; n <= maxN; n++) {
        if (token.length < n) continue;
        for (int i = 0; i <= token.length - n; i++) {
          out.add(token.substring(i, i + n));
        }
      }
    }
    return out;
  }
}
