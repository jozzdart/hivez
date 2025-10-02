/// `Hivez`
///
/// A type-safe, concurrency-safe, production-ready wrapper around
/// [Hive CE] for Dart & Flutter.
///
/// ### Why Hivez?
/// - **Zero setup** → no `openBox`, boxes auto-initialize
/// - **Type-safe** → no `dynamic`, compile-time guarantees
/// - **Unified API** → Box, LazyBox, IsolatedBox — one interface
/// - **Concurrency-safe** → built-in locking, atomic writes
/// - **Production features** → encryption, crash recovery, compaction
/// - **Utilities included** → backup/restore, search, iteration helpers
///
/// ### Box types
/// - `HivezBox<K, T>` → Standard box, fast sync reads
/// - `HivezBoxLazy<K, T>` → Lazy loading for large datasets
/// - `HivezBoxIsolated<K, T>` → Isolate-safe box
/// - `HivezBoxIsolatedLazy<K, T>` → Isolate + lazy combined
///
/// ### Example
/// ```dart
/// final users = HivezBox<int, User>('users');
/// await users.put(1, User('Alice'));
/// final u = await users.get(1); // User('Alice')
/// ```
///
/// Full docs & setup guide: https://pub.dev/packages/hivez
library;

export 'src/src.dart';
