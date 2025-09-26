## Unreleased

- Added optional parameters to `AbstractHivezBox` for supporting more advanced Hive features like encryption, compaction, crash recovery, path, collection, and key comparator
- Added `HivezLazyBox` for lazy boxes and `HivezBox` for regular boxes, `HivezIsolatedBox` for isolated boxes and `HivezIsolatedLazyBox` for isolated lazy boxes

## 0.0.2

- Changed `BaseHiveService` to `BaseHivezBox` for better abstraction and flexibility
- Created core functionality, exceptions and base interfaces for Hivez boxes
- Added future support for all operations including isolated boxes
- Updated dart sdk dependency to support up to 4.0.0
- Updated README.md links

## 0.0.1

Initial release of hivez package.

- Introduced `BaseHiveService<K, T>` for managing Hive boxes:
  - Lazy initialization via `ensureInitialized()` with overridable `onInit()` hook
  - Concurrency-safe operations using `synchronizedWrite` and `synchronizedRead`
  - Guarded `box` getter; throws `HiveServiceInitException` if uninitialized
  - Utilities: `closeBox()`, `deleteFromDisk()`, optional logging via `LogHandler` and `debugLog()`
- Added `HiveServiceInitException` for uninitialized service access
