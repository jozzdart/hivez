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
- [Introduction](#-introduction)
- [`Hive` vs `Hivez`](#-hive-vs-hivez)
- [Introduction & Examples](#-introduction-&-examples)
- [Setup Guide for `hive_ce`](#-setup-guide-for-hive_ce)
- [Clean architecture with `Hivez`](#-clean-architecture-with-hivez)

## ✅ Features

- **Zero setup** – No manual `openBox` or init checks. Boxes auto-initialize on first use.
- **Type-safe API** – No `dynamic`, no runtime surprises. Always the right types at compile time.
- **Unified interface** – One clean API for `Box`, `LazyBox`, `IsolatedBox`, and `IsolatedLazyBox`. Swap implementations with a single line.
- **Concurrency-safe** – Built-in locks ensure atomic writes and isolated reads under heavy async loads.
- **Clean architecture ready** – Decouple storage from business logic with a consistent, testable interface.
- **Production-grade** – Encryption, crash recovery, compaction, and path overrides included.
- **Utility-rich** – Backup/restore (JSON), search helpers, iteration utilities, and full box management tools.
- **Future-proof** – Start simple, scale later. Switch box types without rewriting your app logic.
- **Fully compatible** – 100% Hive under the hood. All features supported, none removed.

No `dynamic` (even for keys), no surprises.

```dart
final users = HivezBox<int, User>('users');
await users.put(1, User('Alice'));
final User? u = await users.get(1);
```

Zero Setup & Auto-Initialization, no more await `Hive.openBox`.

```dart
final settings = HivezBox<String, bool>('settings');
await settings.put('darkMode', true); // no manual init
final darkMode = await settings.get('darkMode');
```

**Unified API Across Box Types**  
`Box`, `LazyBox`, `IsolatedBox` — all with one async interface.  
Switch with a single line, your code stays the same.

```dart
final articles = HivezBoxLazy<String, Article>('articles');
final articles = HivezBoxIsolated<String, Article>('articles');
```

# 🔄 `Hive` vs `Hivez`

_[⤴️ Back](#table-of-contents) → Table of Contents_

| Feature / Concern        | Native Hive                                         | With Hivez                                                                   |
| ------------------------ | --------------------------------------------------- | ---------------------------------------------------------------------------- |
| **Type Safety**          | Uses `dynamic`, requires manual casts               | Strongly typed: `HivezBox<int, User>` guarantees only `User` with `int` keys |
| **Initialization**       | Must manually call `Hive.openBox` and check state   | Auto-initializes on first use, no boilerplate or crashes                     |
| **API Consistency**      | Different APIs for `Box`, `LazyBox`, `IsolatedBox`  | Unified async API for all box types, switch with a single line               |
| **Concurrency**          | Not concurrency-safe out of the box                 | Built-in locks: atomic writes, isolated reads, no race conditions            |
| **Architecture**         | Logic tightly coupled with raw boxes                | Clean, abstracted interface ready for Clean Architecture & DI                |
| **Utilities**            | Only basic CRUD                                     | Backup/restore (JSON), search helpers, iteration tools, box management       |
| **Error Handling**       | Easy to get “Box not open” or type errors           | Guards built-in: no unsafe access, no unchecked casts                        |
| **Production Readiness** | Good for small projects, needs extra care           | Encryption, crash recovery, compaction, isolated boxes — all supported       |
| **Migration / Scaling**  | Switching to LazyBox/IsolatedBox requires rewriting | Swap `HivezBox` → `HivezBoxLazy` or `HivezBoxIsolated` without code changes  |
| **Developer Experience** | Verbose, repetitive boilerplate                     | Cleaner, safer, future-proof abstraction with less code                      |

# 📦 `HivezBox` API Overview

[⤴️ Back](#table-of-contents) → Table of Contents

Hivez provides **four box types** that act as complete, self-initializing services for storing and managing data.  
Unlike raw Hive, you don’t need to worry about opening/closing boxes — the API is unified and stays identical across box types.

### Which Box Should I Use?

- **`HivezBox<K, T>`** → Default choice. Fast, synchronous reads with async writes.
- **`HivezBoxLazy`** → Use when working with **large datasets** where values are only loaded on demand.
- **`HivezBoxIsolated`** → Use when you need **isolate safety** (background isolates or heavy concurrency).
- **`HivezBoxIsolatedLazy`** → Combine **lazy loading + isolate safety** for maximum scalability.

> 💡 Switching between them is a **single-line change**. Your app logic and API calls stay exactly the same — while in raw Hive, this would break your code.

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
  - `toMap()` — Convert full box to `Map<K, T>` (non-lazy boxes)
  - Backup/restore extensions — Export/import as JSON

---

⚡ In short: choose the box type once, and enjoy a **complete, type-safe, async API** everywhere.

# 🔗 Setup Guide for `hive_ce`

To start using Hive in Dart or Flutter, you’ll need the [Hive Community Edition](https://pub.dev/packages/hive_ce) (Hive CE) and the Flutter bindings.
I made this setup guide for you to make it easier to get started with Hive.

- [1. Add the packages](#1-add-the-packages)
- [2. Setting Up `Hive` Adapters](#2-setting-up-hive-adapters)
- [3. Registering Adapters](#3-registering-adapters)
- [4. When Updating/Adding Types](#️-4-when-updatingadding-types)

**It takes less than 2 minutes.**

## 1. Add the packages

One line command to add all packages:

```sh
flutter pub add hive_ce hive_ce_flutter dev:hive_ce_generator dev:build_runner
```

or add the following to your `pubspec.yaml` with the _latest_ versions:

```yaml
dependencies:
  hive_ce: ^2.10.1
  hive_ce_flutter: ^2.2.0

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
import 'package:hive_ce/hive.dart';
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
import 'package:hive_ce_flutter/hive_flutter.dart';
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

_[⤴️ Back](#table-of-contents) → Table of Contents_

## 👋🏻 Introduction

## 🔗 License MIT © Jozz

<p align="center">
  <a href="https://buymeacoffee.com/yosefd99v" target="https://buymeacoffee.com/yosefd99v">
    ☕ Enjoying this package? You can support it here.
  </a>
</p>
