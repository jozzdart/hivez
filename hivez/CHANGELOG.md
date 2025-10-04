## Unreleased

- Added `BoxDecorator` to wrap any `BoxInterface` with additional behavior

## 1.0.2

- **Fix:** Resolved missing exports (in `hivez_flutter`) for generated adapters (`BinaryReader`, `BinaryWriter`, `TypeAdapter`, etc.), which caused build errors when running  
  `dart run build_runner build --delete-conflicting-outputs`.  
  [#23](https://github.com/jozzdart/hivez/issues/23) · [#25](https://github.com/jozzdart/hivez/pull/25)
- Updated README

## 1.0.1

- Added example file for pub.dev
- Updated README.md with more detailed examples and sections

## 1.0.0

- Added proper API comments and documentation
- Removed unnecessary `hive_ce` export inside the `hivez` package
- Added exports from `hive_ce` to the `hivez_flutter` package
- Completed all essential documentation

## 0.0.11

- Created `hivez_flutter` package for Flutter usage to easily import all additional `hive_ce` dependencies. Now all you need is to import `hivez_flutter` instead of `hivez` and `hive_ce_flutter` and `hive_ce` in your Flutter projects (If you don't need to use them directly).

## 0.0.10

- Added `moveKey` method to reassign a value from one key to another (renames the key while preserving the value).
- Added `foreachKey` and `foreachValue` methods to iterate over all keys and values in the box
- Made the base `BoxInterface` class simpler for better abstraction and flexibility
- Added exports from `hive_ce` to the package for ease of use
- Updated the **README** with more detailed examples and better structure with sections Features, Hive vs `Hivez` Comparison, How to Use `Hivez`, Examples, Setup Guide for `hive_ce`

## 0.0.9

- Improved API structure, type safety and made unnecessary public members private
- Improved logging performance by using a function builder instead of a string literal
- Added basic logs to `initialize`, `flush`, `compact`, `deleteFromDisk`, and `closeBox` operations
- Added extensive tests for backup extension methods for all box types testing both JSON and compressed backups and many more tests for all box types
- Fixed missing exports for extension methods
- To improve the auto-completion and code readability, renamed boxes from
  - `HivezBox`
  - `HivezLazyBox`
  - `HivezIsolatedBox`
  - `HivezIsolatedLazyBox`
- to
  - `HivezBox`,
  - `HivezBoxLazy`,
  - `HivezBoxIsolated`,
  - `HivezBoxIsolatedLazy`

## 0.0.8

- Improved performance by removing unnecessary checks and validation while making the package even more type safe and flexible
- Added search extension methods for all box types, and added extensive tests with all box types
  - `search` for searching the box for values that match the search query. It supports pagination, sorting and improved search with multiple search terms.
- Fixed casting issues with isolated boxes

## 0.0.7

- Implemented extensive testing for all box types and functions
- Tests for `put`, `get`, `putAll`, `containsKey`, `keys`, `length`, `isEmpty`, `isNotEmpty`, `delete`, `deleteAt`, `deleteAll`, `clear`, `generateBackupJson`, `restoreBackupJson`, `generateBackupCompressed`, `restoreBackupCompressed`
- Box types tested: `HivezBox`, `HivezLazyBox`, `HivezIsolatedBox`, `HivezIsolatedLazyBox`

## 0.0.6

- Created backup extension methods for all box types, it uses the existing json backup extension methods and compresses the json string using the `shrink` package with compression ratios of 5x-40x
  - `generateBackupCompressed` for generating compressed backups
  - `restoreBackupCompressed` for restoring compressed backups
- Started setting up testing for the package
- Implemented test setup utilities using the `hive_ce_flutter` package
- Added testing dev dependencies

## 0.0.5

- Created backup extension methods for all box types, it saves all data existing in the box to a json string and allows to restore the data from the json string back to the box
  - `generateBackupJson` for generating json backups
  - `restoreBackupJson` for restoring json backups

## 0.0.4

- Added all box types, all ready to use out of the box
  - `HivezBox` for regular boxes
  - `HivezLazyBox` for lazy boxes
  - `HivezIsolatedBox` for regular isolated boxes
  - `HivezIsolatedLazyBox` for lazy isolated boxes

## 0.0.3

- Added abstract boxes
  - `AbstractHivezBox` for lazy and regular boxes
  - `AbstractHivezIsolatedBox` for lazy and regular isolated boxes
- Implemented shared functionality for all boxes

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
