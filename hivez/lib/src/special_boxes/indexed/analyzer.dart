part of 'indexed.dart';

enum Analyzer {
  basic,
  prefix,
  ngram,
}

extension CreateTextAnalyzerExtensions on Analyzer {
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

abstract class TextAnalyzer<T> {
  const TextAnalyzer();
  Iterable<String> analyze(T value);
  static Iterable<String> normalize(String q) => q
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .split(RegExp(r'\s+', unicode: true))
      .where((t) => t.length > 1);

  static TextAnalyzer<T> basic<T>(String Function(T) searchableText) =>
      BasicTextAnalyzer<T>(searchableText);

  static TextAnalyzer<T> prefix<T>(String Function(T) searchableText,
          {int minPrefix = 2, int maxPrefix = 9}) =>
      PrefixTextAnalyzer<T>(searchableText,
          minPrefix: minPrefix, maxPrefix: maxPrefix);

  static TextAnalyzer<T> ngram<T>(String Function(T) searchableText,
          {int minN = 2, int maxN = 6}) =>
      NGramTextAnalyzer<T>(searchableText, minN: minN, maxN: maxN);
}

class BasicTextAnalyzer<T> extends TextAnalyzer<T> {
  final String Function(T value) searchableText;
  const BasicTextAnalyzer(this.searchableText);

  @override
  Iterable<String> analyze(T v) => TextAnalyzer.normalize(searchableText(v));
}

/// Prefix analyzer: generates "he", "hel", "hell", "hello" for each token.
class PrefixTextAnalyzer<T> extends TextAnalyzer<T> {
  final String Function(T) searchableText;
  final int minPrefix;
  final int maxPrefix;
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

/// N-gram analyzer: generates every substring of length [minN]–[maxN].
class NGramTextAnalyzer<T> extends TextAnalyzer<T> {
  final String Function(T) searchableText;
  final int minN;
  final int maxN;
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
