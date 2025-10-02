import 'package:hivez/src/boxes/boxes.dart';

/// Extension providing advanced search and sorting capabilities for [BoxInterface].
///
/// This extension adds a `search` method to any [BoxInterface] implementation,
/// enabling full-text search, multi-term filtering, multi-criteria sorting, and pagination
/// over the values stored in the box. This is especially useful for building
/// responsive UIs or APIs that require efficient querying of local data.
///
/// Example usage:
/// ```dart
/// final results = await box.search(
///   query: 'john doe',
///   searchableText: (user) => '${user.firstName} ${user.lastName}',
///   page: 0,
///   pageSize: 10,
///   sortBy: [SortCriterion((user) => user.lastName)],
/// );
/// ```
extension SearchExtensionMethod<K, T> on BoxInterface<K, T> {
  /// Performs a full-text search, optional multi-criteria sort, and pagination on the box values.
  ///
  /// - [query]: The search string. Split into terms (by whitespace), all of which must be present
  ///   (case-insensitive) in the value as determined by [searchableText]. If empty, all values are returned.
  /// - [searchableText]: A function mapping a value to a string to be searched.
  /// - [page]: Optional page number (zero-based) for pagination. If null, all results are returned.
  /// - [pageSize]: Number of items per page (default: 20).
  /// - [sortBy]: Optional list of [SortCriterion]s to sort the results by multiple fields.
  ///
  /// Returns a [Future] that completes with a list of matching values, sorted and paginated as requested.
  ///
  /// Throws [BoxNotInitializedException] if the box is not initialized.
  Future<List<T>> search({
    required String query,
    required String Function(T item) searchableText,
    int? page,
    int pageSize = 20,
    List<SortCriterion<T>>? sortBy,
  }) async {
    await ensureInitialized();

    // Split the query into lowercase search terms, ignoring empty terms.
    final searchTerms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // If no search terms, return all values; otherwise, filter by all terms.
    final filtered = searchTerms.isEmpty
        ? await getAllValues()
        : await getValuesWhere((item) {
            final text = searchableText(item).toLowerCase();
            return searchTerms.every((term) => text.contains(term));
          });

    final resultList = filtered.toList();

    // Apply multi-criteria sorting if specified.
    if (sortBy != null && sortBy.isNotEmpty) {
      resultList.sort((a, b) {
        for (final criterion in sortBy) {
          final result = criterion.compare(a, b);
          if (result != 0) return result;
        }
        return 0;
      });
    }

    // If no pagination requested, return the full result list.
    if (page == null) return resultList;

    // Return the paginated results.
    return _paginate(resultList, page, pageSize);
  }

  /// Returns a sublist of [items] corresponding to the given [page] and [pageSize].
  ///
  /// If the requested page is out of range, returns an empty list.
  List<T> _paginate(List<T> items, int page, int pageSize) {
    final start = page * pageSize;
    final end = start + pageSize;
    return items.sublist(start, end.clamp(0, items.length));
  }
}

/// Describes a sorting criterion for use with [SearchExtensionMethod.search].
///
/// Allows sorting by a field or computed value, in ascending or descending order.
/// Multiple [SortCriterion]s can be combined for multi-level sorting.
///
/// Example:
/// ```dart
/// [
///   SortCriterion((user) => user.lastName),
///   SortCriterion((user) => user.firstName, ascending: false),
/// ]
/// ```
class SortCriterion<T> {
  /// Function that extracts a [Comparable] value from an item for sorting.
  final Comparable Function(T item) selector;

  /// Whether to sort in ascending order (default: true).
  final bool ascending;

  /// Creates a [SortCriterion] with the given [selector] and [ascending] flag.
  const SortCriterion(this.selector, {this.ascending = true});

  /// Compares two items [a] and [b] according to the selector and order.
  ///
  /// Returns a negative value if [a] should come before [b], positive if after, or zero if equal.
  int compare(T a, T b) {
    final comparison = selector(a).compareTo(selector(b));
    return ascending ? comparison : -comparison;
  }
}
