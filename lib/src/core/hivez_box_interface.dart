import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

abstract class HivezBoxInterface<K, T, B>
    implements
        HivezBoxFunctions,
        HivezBoxExternalFunctions<B>,
        HivezBoxOperationsWrite<K, T>,
        HivezBoxOperationsRead<K, T, B>,
        HivezBoxOperationsDelete<K, T>,
        HivezBoxOperationsQuery<K, T>,
        HivezBoxInfoGetters {}

abstract class HivezBoxOperationsWrite<K, T> {
  Future<void> put(K key, T value);
  Future<void> putAll(Map<K, T> entries);
  Future<void> putAt(int index, T value);
  Future<int> add(T value);
  Future<void> addAll(Iterable<T> values);
}

abstract class HivezBoxOperationsDelete<K, T> {
  Future<void> delete(K key);
  Future<void> deleteAt(int index);
  Future<void> deleteAll(Iterable<K> keys);
  Future<void> clear();
}

abstract class HivezBoxInfoGetters {
  Future<bool> get isEmpty;
  Future<bool> get isNotEmpty;
  Future<int> get length;
}

abstract class HivezBoxOperationsRead<K, T, B> {
  Future<K> keyAt(int index);
  Future<T?> valueAt(int index);
  Future<T?> getAt(int index);
  Future<bool> containsKey(K key);
  Future<Iterable<K>> getAllKeys();
  Future<T?> get(K key, {T? defaultValue});
  Future<Iterable<T>> getAllValues();
  Stream<BoxEvent> watch(K key);
}

abstract class HivezBoxOperationsQuery<K, T> {
  Future<Iterable<T>> getValuesWhere(bool Function(T) condition);
  Future<T?> firstWhereOrNull(bool Function(T item) condition);
  Future<T?> firstWhereContains(
    String query, {
    required String Function(T item) searchableText,
  });
}

abstract class HivezBoxFunctions {
  Future<void> ensureInitialized();
  Future<void> deleteFromDisk();
  Future<void> closeBox();
  Future<void> flushBox();
  Future<void> compactBox();
}

abstract class HivezBoxExternalFunctions<BoxType> {
  @protected
  BoxType hiveGetBox();

  @protected
  Future<BoxType> hiveOpenBox();
}
