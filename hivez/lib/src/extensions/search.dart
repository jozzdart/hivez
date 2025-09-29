import 'package:hivez/src/boxes/boxes.dart';

extension SearchExtensionMethod<K, T> on BoxInterface<K, T> {
  Future<List<T>> search({
    required String query,
    required String Function(T item) searchableText,
    int? page,
    int pageSize = 20,
    List<SortCriterion<T>>? sortBy,
  }) async {
    await ensureInitialized();

    final searchTerms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final filtered = searchTerms.isEmpty
        ? await getAllValues()
        : await getValuesWhere((item) {
            final text = searchableText(item).toLowerCase();
            return searchTerms.every((term) => text.contains(term));
          });

    final resultList = filtered.toList();

    if (sortBy != null && sortBy.isNotEmpty) {
      resultList.sort((a, b) {
        for (final criterion in sortBy) {
          final result =
              criterion.compare(a, b); // <- Use the encapsulated logic
          if (result != 0) return result;
        }
        return 0;
      });
    }

    if (page == null) return resultList;

    return _paginate(resultList, page, pageSize);
  }

  List<T> _paginate(List<T> items, int page, int pageSize) {
    final start = page * pageSize;
    final end = start + pageSize;
    return items.sublist(start, end.clamp(0, items.length));
  }
}

class SortCriterion<T> {
  final Comparable Function(T item) selector;
  final bool ascending;

  const SortCriterion(this.selector, {this.ascending = true});

  int compare(T a, T b) {
    final comparison = selector(a).compareTo(selector(b));
    return ascending ? comparison : -comparison;
  }
}
