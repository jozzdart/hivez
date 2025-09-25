## Unreleased

- Changed `BaseHiveService` to `AbstractHiveService` for better abstraction and flexibility
- Added optional parameters to `AbstractHiveService` for supporting more advanced Hive features like encryption, compaction, crash recovery, path, collection, and key comparator
- Added `LazyHiveService` for lazy boxes and `HiveService` for regular boxes

## 0.0.1

Initial release of hivez package.

- Introduced `BaseHiveService<K, T>` for managing Hive boxes:
  - Lazy initialization via `ensureInitialized()` with overridable `onInit()` hook
  - Concurrency-safe operations using `synchronizedWrite` and `synchronizedRead`
  - Guarded `box` getter; throws `HiveServiceInitException` if uninitialized
  - Utilities: `closeBox()`, `deleteFromDisk()`, optional logging via `LogHandler` and `debugLog()`
- Added `HiveServiceInitException` for uninitialized service access
