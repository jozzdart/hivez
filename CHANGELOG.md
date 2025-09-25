## 0.0.1

Initial release of hivez package.

- Introduced `BaseHiveService<K, T>` for managing Hive boxes:
  - Lazy initialization via `ensureInitialized()` with overridable `onInit()` hook
  - Concurrency-safe operations using `synchronizedWrite` and `synchronizedRead`
  - Guarded `box` getter; throws `HiveServiceInitException` if uninitialized
  - Utilities: `closeBox()`, `deleteFromDisk()`, optional logging via `LogHandler` and `debugLog()`
- Added `HiveServiceInitException` for uninitialized service access
