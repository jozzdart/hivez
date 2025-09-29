![img](https://i.imgur.com/XgI3sfn.png)

<h3 align="center"><i>Hive, but safer, simpler, and smarter. Ready for production.</i></h3>
<p align="center">
        <img src="https://img.shields.io/codefactor/grade/github/jozzdart/hivez/main?style=flat-square">
        <img src="https://img.shields.io/github/license/jozzdart/hivez?style=flat-square">
        <img src="https://img.shields.io/pub/points/hivez?style=flat-square">
        <img src="https://img.shields.io/pub/v/hivez?style=flat-square">
        
</p>
<p align="center">
  <a href="https://buymeacoffee.com/yosefd99v" target="https://buymeacoffee.com/yosefd99v">
    <img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-Support (:-blue?logo=buymeacoffee&style=flat-square" />
  </a>
</p>

Meet `Hivez` — the smart, type-safe way to use **_Hive_** (using the [`hive_ce` package](https://pub.dev/packages/hive_ce)) in Dart and Flutter. With a unified API, zero setup, and built-in utilities for search, backups, and syncing, Hivez makes every box concurrency-safe, future-proof, and production-ready — while keeping full Hive compatibility.

#### Table of Contents

- [Features](#-features)
- [Hive vs `Hivez` Comparison](#hive-vs-hivez)
- [How to Use `Hivez`](#-how-to-use-hivez)
  - [Which `Box` Should I Use?](#which-box-should-i-use)
  - [Available Methods](#-available-methods)
  - [Examples](#examples)
- [Setup Guide for `hive_ce`](#-setup-guide-for-hive_ce)
- [Quick Setup `hive_ce` (no explanations)](#-quick-setup-hive_ce-no-explanations)

## ✅ Features

- **Zero setup** – no manual `openBox`, auto-init on first use
- **Type-safe** – no `dynamic`, compile-time guarantees
- **Unified API** – one interface for Box, Lazy, Isolated
- **Concurrency-safe** – atomic writes, safe reads
- **Clean architecture** – decoupled, testable design
- **Production-ready** – encryption, crash recovery, compaction
- **Utility-rich** – backup/restore, search, iteration, box tools
- **Future-proof** – swap box types with one line
- **Hive-compatible** – 100% features, zero loss

**Type-safe** – no `dynamic`, no surprises

```dart
final users = HivezBox<int, User>('users');
await users.put(1, User('Alice'));
final u = await users.get(1); // User('Alice')
```

**Zero setup** – no `openBox`, auto-init on first use

```dart
final settings = HivezBox<String, bool>('settings');
await settings.put('darkMode', true);
final dark = await settings.get('darkMode'); // true
```

**Unified API** – Box, Lazy, Isolated — same interface, swap with one line

```dart
final a = HivezBoxLazy<String, Article>('articles');
final b = HivezBoxIsolated<String, Article>('articles');
```

# Hive vs `Hivez`

_[⤴️ Back](#table-of-contents) → Table of Contents_

| Feature / Concern   | Native Hive                              | With Hivez                                                      |
| ------------------- | ---------------------------------------- | --------------------------------------------------------------- |
| **Type Safety**     | `dynamic` with manual casts              | `HivezBox<int, User>` guarantees correct types                  |
| **Initialization**  | Must call `Hive.openBox` and check state | Auto-initializes on first use, no boilerplate                   |
| **API Consistency** | Different APIs for Box types             | Unified async API, switch with a single line                    |
| **Concurrency**     | Not concurrency-safe                     | Built-in locks: atomic writes, safe reads                       |
| **Architecture**    | Logic tied to raw boxes                  | Abstracted interface, fits Clean Architecture & DI              |
| **Utilities**       | Basic CRUD only                          | Backup/restore, search helpers, iteration, box management       |
| **Production**      | Needs extra care for scaling & safety    | Encryption, crash recovery, compaction, isolated boxes included |
| **Migration**       | Switching box types requires rewrites    | Swap `HivezBox` ↔ `HivezBoxLazy`/`HivezBoxIsolated` seamlessly  |
| **Dev Experience**  | Verbose boilerplate, error-prone         | Cleaner, safer, future-proof, less code                         |

# 📦 How to Use `Hivez`

[⤴️ Back](#table-of-contents) → Table of Contents

Hivez provides **four box types** that act as complete, self-initializing services for storing and managing data.  
Unlike raw Hive, you don’t need to worry about opening/closing boxes — the API is unified and stays identical across box types.

- [Which `Box` Should I Use?](#which-box-should-i-use)
- [Available Methods](#-available-methods)
- [Examples](#examples)

### Which `Box` Should I Use?

- **`HivezBox`** → Default choice. Fast, synchronous reads with async writes.
- **`HivezBoxLazy`** → Use when working with **large datasets** where values are only loaded on demand.
- **`HivezBoxIsolated`** → Use when you need **isolate safety** (background isolates or heavy concurrency).
- **`HivezBoxIsolatedLazy`** → Combine **lazy loading + isolate safety** for maximum scalability.

> 💡 Switching between them is a **single-line change**. Your app logic and API calls stay exactly the same — while in raw Hive, this would break your code.  
> ⚠️ **Note on isolates:** The API is identical across all box types, but using `Isolated` boxes requires you to properly set up Hive with isolates. If you’re not familiar with isolate management in Dart/Flutter, it’s safer to stick with **`HivezBox`** or **`HivezBoxLazy`**.

## 🔧 Available Methods

All `HivezBox` types share the same complete API:

- **Write operations**

  - `put(key, value)` — Insert or update a value by key
  - `putAll(entries)` — Insert/update multiple entries at once
  - `putAt(index, value)` — Update value at a specific index
  - `add(value)` — Auto-increment key insert
  - `addAll(values)` — Insert multiple values sequentially
  - `moveKey(oldKey, newKey)` — Move value from one key to another

- **Delete operations**

  - `delete(key)` — Remove a value by key
  - `deleteAt(index)` — Remove value at index
  - `deleteAll(keys)` — Remove multiple keys
  - `clear()` — Delete all data in the box

- **Read operations**

  - `get(key)` — Retrieve value by key (with optional `defaultValue`)
  - `getAt(index)` — Retrieve value by index
  - `valueAt(index)` — Alias for `getAt`
  - `getAllKeys()` — Returns all keys
  - `getAllValues()` — Returns all values
  - `keyAt(index)` — Returns key at given index
  - `containsKey(key)` — Check if key exists
  - `length` — Number of items in box
  - `isEmpty` / `isNotEmpty` — Quick state checks
  - `watch(key)` — Listen to changes for a specific key

- **Query helpers**

  - `getValuesWhere(condition)` — Filter values by predicate
  - `firstWhereOrNull(condition)` — Returns first matching value or `null`
  - `firstWhereContains(query, searchableText)` — Search string fields
  - `foreachKey(action)` — Iterate keys asynchronously
  - `foreachValue(action)` — Iterate values asynchronously

- **Box management**

  - `ensureInitialized()` — Safely open box if not already open
  - `deleteFromDisk()` — Permanently delete box data
  - `closeBox()` — Close box in memory
  - `flushBox()` — Write pending changes to disk
  - `compactBox()` — Compact file to save space

- **Extras**

  - `generateBackupJson()` — Export all data as JSON
  - `restoreBackupJson()` — Import all data from JSON
  - `generateBackupCompressed()` — Export all data as compressed binary
  - `restoreBackupCompressed()` — Import all data from compressed binary
  - `toMap()` — Convert full box to `Map<K, T>` (non-lazy boxes)
  - `search(query, searchableText, {page, pageSize, sortBy})` — Full-text search with optional pagination & sorting

## Examples

> Before diving in — make sure you’ve set up Hive correctly with adapters.  
> The setup takes **less than 1 minute** and is explained here: [Setup Guide](#-setup-guide-for-hive_ce).  
> Once Hive is set up, you can use `Hivez` right away:

#### ➕ Put & Get

```dart
final box = HivezBox<int, String>('notes');
await box.put(1, 'Hello');
final note = await box.get(1); // "Hello"
```

#### 📥 Add & Retrieve by Index

```dart
final id = await box.add('World');   // auto index (int)
final val = await box.getAt(id);     // "World"
```

#### ✏️ Update & Move Keys

```dart
await box.put(1, 'Updated');
await box.moveKey(1, 2); // value moved from key 1 → key 2
```

#### ❌ Delete & Clear

```dart
await box.delete(2);
await box.clear(); // remove all
```

#### 🔑 Keys & Values

```dart
final keys = await box.getAllKeys();     // Iterable<int>
final vals = await box.getAllValues();  // Iterable<String>
```

#### 🔍 Queries

```dart
final match = await box.firstWhereOrNull((v) => v.contains('Hello'));
final contains = await box.containsKey(1); // true / false
```

#### 🔄 Iteration Helpers

```dart
await box.foreachKey((k) async => print(k));
await box.foreachValue((k, v) async => print('$k:$v'));
```

#### 📊 Box Info

```dart
final count = await box.length;
final empty = await box.isEmpty;
```

#### ⚡ Utilities

```dart
await box.flushBox();    // write to disk
await box.compactBox();  // shrink file
await box.deleteFromDisk(); // remove permanently
```

#### 👀 Watch for Changes

```dart
box.watch(1).listen((event) {
  print('Key changed: ${event.key}');
});
```

> ✅ This is just with `HivezBox`.  
> The same API works for `HivezBoxLazy`, `HivezBoxIsolated`, and `HivezBoxIsolatedLazy`.

_[⤴️ Back](#table-of-contents) → Table of Contents_

# 🔗 Setup Guide for `hive_ce`

To start using Hive in Dart or Flutter, you’ll need the [Hive Community Edition](https://pub.dev/packages/hive_ce) (Hive CE) and the Flutter bindings.
I made this setup guide for you to make it easier to get started with Hive.

- [1. Add the packages](#1-add-the-packages)
- [2. Setting Up `Hive` Adapters](#2-setting-up-hive-adapters)
- [3. Registering Adapters](#3-registering-adapters)
- [4. When Updating/Adding Types](#️-4-when-updatingadding-types)

**It takes less than 1 minute.**

## 1. Add the packages

One line command to add all packages:

```sh
flutter pub add hivez_flutter dev:hive_ce_generator dev:build_runner
```

or add the following to your `pubspec.yaml` with the _latest_ versions:

```yaml
dependencies:
  hivez_flutter: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.7
  hive_ce_generator: ^1.8.2
```

## 2. Setting Up `Hive` Adapters

Hive works out of the box with core Dart types (`String`, `int`, `double`, `bool`, `DateTime`, `Uint8List`, `List`, `Map`…), but if you want to store **custom classes or enums**, you must register a **TypeAdapter**.

With `Hive` you can generate multiple adapters at once with the `@GenerateAdapters` annotation. For all enums and classes you want to store, you need to register an adapter.

Let's say you have the following classes and enums:

```dart
class Product {
  final String name;
  final double price;
  final Category category;
}
```

```dart
enum Category {
  electronics,
  clothing,
  books,
  other,
}
```

To generate the adapters, you need to:

1. Create a folder named `hive` somewhere inside your `lib` folder
2. Inside this `hive` folder create a file named `hive_adapters.dart`
3. Add the following code to the file:

```dart
// hive/hive_adapters.dart
import 'package:hivez_flutter/hivez_flutter.dart';
import '../product.dart';

part 'hive_adapters.g.dart';

@GenerateAdapters([
  AdapterSpec<Product>(),
  AdapterSpec<Category>(),
])
class HiveAdapters {}
```

Then run this command to generate the adapters:

```sh
dart run build_runner build --delete-conflicting-outputs
```

This creates the following files (do not delete/modify these files):

```
lib/hive/hive_adapters.g.dart
lib/hive/hive_adapters.g.yaml
lib/hive/hive_registrar.g.dart
```

## 3. Registering Adapters

Then in main.dart before running the app, add the following code:
Register adapters **before running the app**:

```dart
import 'package:flutter/material.dart';
import 'package:hivez_flutter/hivez_flutter.dart';
import 'hive/hive_registrar.g.dart'; // generated
import 'product.dart';

Future<void> main() async {
  await Hive.initFlutter(); // Initialize Hive for Flutter
  Hive.registerAdapters(); // Register all adapters in one line (Hive CE only)
  runApp(const MyApp());
}
```

Done! You can now use the `Hivez` package to store and retrieve custom objects.

### ⚠️ 4. When Updating/Adding Types

If you add new classes or enums, or change existing ones (like adding fields or updating behavior),  
just include them in your `hive_adapters.dart` file and re-run the build command:

```sh
dart run build_runner build --delete-conflicting-outputs
```

That’s it — Hive will regenerate the adapters automatically.

## ⚡ Quick Setup `hive_ce` (no explanations)

_[⤴️ Back](#table-of-contents) → Table of Contents_

> For all returning users, you can use the following quick setup to get started quickly.

1. Add the packages

```sh
flutter pub add hivez_flutter dev:hive_ce_generator dev:build_runner
```

2. Setting Up Adapters in the file `lib/hive/hive_adapters.dart`

```dart
// lib/hive/hive_adapters.dart
import 'package:hivez_flutter/hivez_flutter.dart';
import '../product.dart';

part 'hive_adapters.g.dart';

@GenerateAdapters([
  AdapterSpec<Product>(),
  AdapterSpec<Category>(),
])
class HiveAdapters {}
```

3. Run the build command

```sh
dart run build_runner build --delete-conflicting-outputs
```

4. Registering Adapters in the file `main.dart`

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:hivez_flutter/hivez_flutter.dart';
import 'hive/hive_registrar.g.dart';

Future<void> main() async {
  await Hive.initFlutter();
  Hive.registerAdapters();
  runApp(const MyApp());
}
```

## 🔗 License MIT © Jozz

<p align="center">
  <a href="https://buymeacoffee.com/yosefd99v" target="https://buymeacoffee.com/yosefd99v">
    ☕ Enjoying this package? You can support it here.
  </a>
</p>
