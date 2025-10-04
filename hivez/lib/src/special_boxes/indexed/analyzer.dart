part of 'indexed.dart';

abstract class TextAnalyzer<T> {
  const TextAnalyzer();
  Iterable<String> analyze(T value);
  static Iterable<String> normalize(String q) => q
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .split(RegExp(r'\s+', unicode: true))
      .where((t) => t.length > 1);
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
  const PrefixTextAnalyzer(this.searchableText, {this.minPrefix = 2});

  @override
  Iterable<String> analyze(T v) {
    final tokens = TextAnalyzer.normalize(searchableText(v));
    final result = <String>[];
    for (final t in tokens) {
      for (int i = minPrefix; i <= t.length; i++) {
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
  const NGramTextAnalyzer(this.searchableText, {this.minN = 2, this.maxN = 5});

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
