part of 'core.dart';

/// Defines the complete contract for all operational methods and getters
/// that a native Hive box exposes in Hivez.
///
/// This interface provides all standard CRUD, query, management, and state
/// operations available to a Hive box, ensuring a consistent API for both
/// production and testing contexts. All regular, lazy, and isolated box
/// implementations conform to this API surface.
///
/// Type parameters:
///   - [K]: Type of keys in the box.
///   - [T]: Type of values stored in the box.
abstract class HiveBoxInterface<K, T> {
  /// Const constructor for a box interface.
  const HiveBoxInterface();

  /// Returns `true` if the box contains no elements.
  Future<bool> get isEmpty;

  /// Returns `true` if the box contains at least one element.
  Future<bool> get isNotEmpty;

  /// Whether the underlying Hive box is currently open.
  bool get isOpen;

  /// Whether this box is running in an isolated (background) context.
  bool get isIsolated;

  /// Whether this box is a lazy box (values loaded on demand).
  bool get isLazy;

  /// The number of key-value pairs in the box.
  Future<int> get length;

  /// The unique name of the box.
  String get name;

  /// The resolved storage path for this box, if set.
  String? get path;

  /// Adds a value to the box using an auto-incremented key (if supported).
  ///
  /// Returns the generated key or index.
  Future<int> add(T value);

  /// Adds multiple values to the box using auto-incremented keys (if supported).
  Future<Iterable<int>> addAll(Iterable<T> values);

  /// Removes all key-value pairs from the box.
  Future<void> clear();

  /// Closes the box, releasing all resources.
  Future<void> closeBox();

  /// Compacts the box, removing unused space.
  Future<void> compactBox();

  /// Returns `true` if the box contains the given [key].
  Future<bool> containsKey(K key);

  /// Deletes the value associated with the given [key].
  Future<void> delete(K key);

  /// Deletes the values associated with the given [keys].
  Future<void> deleteAll(Iterable<K> keys);

  /// Deletes the value at the specified [index].
  Future<void> deleteAt(int index);

  /// Deletes the box from disk.
  Future<void> deleteFromDisk();

  /// Inserts a new key-value pair into the box.
  Future<void> put(K key, T value);

  /// Inserts multiple key-value pairs into the box.
  Future<void> putAll(Map<K, T> entries);

  /// Inserts a new key-value pair into the box at the specified [index].
  Future<void> putAt(int index, T value);

  /// Flushes any pending changes to disk.
  Future<void> flushBox();

  /// Returns the value for the given [key], or null if not found.
  Future<T?> get(K key, {T? defaultValue});

  /// Returns the value at the specified [index], or `null` if not found.
  Future<T?> getAt(int index);

  /// Returns the key at the specified [index]. or `null` if not found.
  Future<K?> keyAt(int index);

  /// Watches for changes to the value associated with [key].
  ///
  /// Emits [BoxEvent]s when the value changes.
  Stream<BoxEvent> watch(K key);

  /// Returns all keys in the box.
  Future<Iterable<K>> getAllKeys();

  /// Returns all values in the box.
  Future<Iterable<T>> getAllValues();

  /// Returns a map containing all key-value pairs in the box.
  Future<Map<K, T>> toMap();
}
