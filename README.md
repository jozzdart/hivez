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
- [`IndexedBox` (Ultra Fast Searches)](#-indexedbox--ultra-fast-full-text-search-for-hive)
  - [Benchmarks](#benchmarks)
  - [Quick Start](#-instantly-switch-from-a-normal-box-even-from-hive)
  - [Examples](#indexedbox---examples)
  - [Settings & Options](#-settings--options)
  - [Analyzers](#-analyzer--how-text-is-broken-into-tokens)
- [Clean Architecture with `Hivez`](#clean-architecture-with-hivez)
- [FAQ / Common Pitfalls](#-faq--common-pitfalls)
- [Performance & Safety](#performance--safety)
- [Why `Hivez`?](#why-hivez)
- [More `jozz` Packages](#-more-jozz-packages)

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
| **Concurrency**     | Not concurrency-safe (in original Hive)  | Built-in locks: atomic writes, safe reads                       |
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
  - `getKeysWhere(condition)` — Filter keys by predicate
  - `firstWhereOrNull(condition)` — Returns first matching value or `null`
  - `firstKeyWhere(condition)` — Returns first matching key or `null`
  - `firstWhereContains(query, searchableText)` — Search string fields
  - `foreachKey(action)` — Iterate keys asynchronously
  - `foreachValue(action)` — Iterate values asynchronously
  - `searchKeyOf(value)` — Find key for a given value

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
  - `toMap()` — Convert full box to `Map<K, T>`
  - `estimateSizeBytes()` — Approximate in-memory size of all keys and values (bytes)
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

# 🔗 Setup Guide for `hive_ce`

_[⤴️ Back](#table-of-contents) → Table of Contents_

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

# 🚀 `IndexedBox` — Ultra-Fast Full-Text Search for Hive

_[⤴️ Back](#table-of-contents) → Table of Contents_

**What it is:** a drop-in replacement for `HivezBox` that adds a tiny **on-disk inverted index**.
You keep the **same API**, but get **instant keyword/prefix/substring search** with ~**`1–3 ms`** queries on thousands of items.

### Why use it:

- **Blazing search:** stop scanning; lookups hit the index.
  - _50,000 items:_ **4149.60 ms → 2.46 ms** (~**1,687×** faster).
  - _500 items:_ **125.20 ms → 1.10 ms** (~**114×** faster).
- **Zero friction:** same `Hivez` API + `search()`/`searchKeys()` helpers.
- **Robust by design:** journaled writes, auto-rebuild on mismatch, and an LRU cache for hot tokens.
- **Configurable:** choose `basic`, `prefix`, or `ngram` analyzers; toggle AND/OR matching; optional result verification.

```dart
final articles = indexedBox.search('flut dart dev'); // Blazing fast search
```

> Heads-up: writes cost more than a plain box (the index is maintained on each mutation). If you do heavy bulk inserts, you can batch with `putAll` and still enjoy ultra-fast reads.

- [**Benchmarks** - how fast it is](#benchmarks)
- [**Instantly `Switch` from a Normal Box** (Even from Hive!)](#-instantly-switch-from-a-normal-box-even-from-hive)
- [**Examples** - how to use `IndexedBox`](#indexedbox---examples)
- [**Settings & Options** - how to tune it](#-settings--options)
- [**Analyzers** - how text is broken into tokens](#-analyzer--how-text-is-broken-into-tokens)

## Benchmarks

#### 🔎 Full-text search (query)

| Items in box | `Box` (avg `ms`) | `IndexedBox` (avg ms) |  Improvement |
| ------------ | ---------------: | --------------------: | -----------: |
| 100          |            11.50 |              **1.56** |     ≈ **7×** |
| 1,000        |            85.14 |              **1.42** |    ≈ **60×** |
| 5,000        |           426.87 |              **1.34** |   ≈ **319×** |
| 10,000       |           833.39 |              **1.43** |   ≈ **583×** |
| 50,000       |          4149.68 |              **2.46** | ≈ **1,687×** |

#### 📥 Bulk inserts (put many)

| Items inserted per run | `Box` (avg `ms`) | `IndexedBox` (avg `ms`) | Cost of indexing |
| ---------------------- | ---------------: | ----------------------: | ---------------: |
| 100                    |             1.32 |                   25.57 |        ≈ **19×** |
| 1,000                  |             1.78 |                   32.72 |        ≈ **18×** |
| 5,000                  |             5.92 |                   94.96 |        ≈ **16×** |
| 10,000                 |            13.47 |                  177.99 |        ≈ **13×** |
| 50,000                 |            56.53 |                  830.24 |        ≈ **14×** |

> Writes are naturally slower on `IndexedBox` due to index maintenance — but searches are **orders of magnitude faster**, which is ideal for text-heavy or search-first workloads.

### 🔄 Instantly Switch from a Normal Box (Even from Hive!)

You don’t need to migrate or rebuild anything — `IndexedBox` is a **drop-in upgrade** for your existing Hive or Hivez boxes.
It reads all your current data, keeps it fully intact, and automatically creates a search index behind the scenes.

All the same CRUD functions (`put`, `get`, `delete`, `foreachValue`, etc.) still work exactly the same —
you just gain ultra-fast search on top.
(See [Available Methods](#-available-methods) for the full API list.)

#### Example — from Hive 🐝 → IndexedBox ⚡

```dart
// Before: plain Hive or Hivez box
final notes = Hive.box<Note>('notes'); //or: HivezBox<int, Note>('notes');

// After: one-line switch to IndexedBox
final notes = IndexedBox<int, Note>('notes', searchableText: (n) => n.content);
```

> That’s it — your data is still there, no re-saving needed.  
> When the box opens for the first time, the index is built automatically (a one-time process).  
> After that, all writes and deletes update the index in real time.

#### Now you can search instantly

```dart
final results = await notes.search('meeting notes');
print(results); // [Note(...), Note(...)]
```

✅ Keeps all your existing data  
✅ Works even if the box was created with raw Hive  
✅ Same methods and API — just faster, smarter, searchable

> 💡 You can freely switch back and forth between `HivezBox` and `IndexedBox`.  
> The data always stays compatible — `IndexedBox` simply adds its own index boxes under the hood.

# `IndexedBox` - Examples

> _[⤴️ Back](#-indexedbox--ultra-fast-full-text-search-for-hive) → IndexedBox_

### 📦 Create an `IndexedBox`

This works just like a normal `HivezBox`, but adds a built-in **on-disk index** for fast text search.

```dart
final box = IndexedBox<String, Article>(
  'articles',
  searchableText: (a) => '${a.title} ${a.content}',
);
```

That’s it — no adapters, no schema, no rebuilds.

### ➕ Add some data

You can insert items the same way as a normal Hive box:

```dart
await box.putAll({
  '1': Article('Flutter and Dart', 'Cross-platform development made easy'),
  '2': Article('Hive Indexing', 'Instant full-text search with IndexedBox'),
  '3': Article('State Management', 'Cubit, Bloc, and Provider compared'),
});
```

### 🔍 Search instantly

Now you can query by **any keyword**, **prefix**, or even **multiple terms**:

```dart
final results = await box.search('flut dev');
print(results); // [Article('Flutter and Dart', ...)]
```

It’s **case-insensitive**, **prefix-aware**, and **super fast** — usually **1–3 ms** per query.

---

### 🔑 Or just get the matching keys

```dart
final keys = await box.searchKeys('hive');
print(keys); // ['2']
```

Perfect if you want to fetch or lazy-load values later.

---

### ⚙️ Tune it your way

You can control how matching works:

```dart
// Match ANY term instead of all
final relaxed = IndexedBox<String, Article>(
  'articles_any',
  searchableText: (a) => a.title,
  matchAllTokens: false,
);
```

Or pick a different text analyzer for **substring** or **prefix** matching:

```dart
analyzer: Analyzer.ngram, // "hel" matches "Hello"
```

> Done.
> You now have a **self-maintaining**, **crash-safe**, **indexed** Hive box that supports blazing-fast search — without changing how you use Hive.

# 🔧 Settings & Options

_[⤴️ Back](#-indexedbox--ultra-fast-full-text-search-for-hive) → IndexedBox_

`IndexedBox` is designed to be flexible — it can act like a fast keyword indexer, a prefix search engine, or even a lightweight substring matcher.
The constructor exposes several **tunable options** that let you decide **how results are matched, cached, and verified**.

- [**`matchAllTokens`** - AND vs OR Logic](#matchalltokens--and-vs-or-logic)
- [**`tokenCacheCapacity`** - LRU Cache Size](#tokencachecapacity--lru-cache-size)
- [**`verifyMatches`** - Guard Against Stale Index](#verifymatches--guard-against-stale-index)
- [**`keyComparator`** - Custom Result Ordering](#keycomparator--custom-result-ordering)
- [**`analyzer`** - How Text Is Broken into Tokens](#analyzer--how-text-is-broken-into-tokens)

---

### `matchAllTokens` – AND vs OR Logic

**What it does:**
Determines whether all tokens in the query must appear in a value (**AND** mode) or if any of them is enough (**OR** mode).

| Mode             | Behavior             | Example Query | Matches                                                                 |
| ---------------- | -------------------- | ------------- | ----------------------------------------------------------------------- |
| `true` (default) | Match **all** tokens | `"flut dart"` | `"Flutter & Dart Tips"` ✅<br>`"Dart Packages"` ❌<br>`"Flutter UI"` ❌ |
| `false`          | Match **any** token  | `"flut dart"` | `"Flutter & Dart Tips"` ✅<br>`"Dart Packages"` ✅<br>`"Flutter UI"` ✅ |

**When to use:**

- `true` → For precise filtering (e.g. “all words must appear”)
- `false` → For broad suggestions or autocomplete

```dart
final strict = IndexedBox<String, Article>(
  'articles',
  searchableText: (a) => a.title,
  matchAllTokens: true, // must contain all words
);

final loose = IndexedBox<String, Article>(
  'articles_any',
  searchableText: (a) => a.title,
  matchAllTokens: false, // any word is enough
);
```

---

### `tokenCacheCapacity` – LRU Cache Size

**What it does:**
Controls how many **token → key sets** are cached in memory.
Caching avoids reading from disk when the same term is searched repeatedly.

| Cache Size      | Memory Use                        | Speed Benefit                               |
| --------------- | --------------------------------- | ------------------------------------------- |
| `0`             | No cache (every search hits disk) | 🔽 Slowest                                  |
| `512` (default) | Moderate RAM (≈ few hundred KB)   | ⚡ 100× faster repeated queries             |
| `5000+`         | Larger memory footprint           | 🔥 Ideal for large datasets or autocomplete |

**When to use:**

- Small cache (≤256) → occasional lookups, low memory
- Default (512) → balanced for most apps
- Large (2000–5000) → high-volume search UIs or live autocomplete

```dart
final box = IndexedBox<String, Product>(
  'products',
  searchableText: (p) => '${p.name} ${p.brand}',
  tokenCacheCapacity: 1024, // keep up to 1024 tokens in RAM
);
```

---

### `verifyMatches` – Guard Against Stale Index

**What it does:**
Re-checks each result against the analyzer before returning it, ensuring that
the value still contains the query terms (useful after manual box edits).

**Trade-off:** adds a small CPU cost per result.

| Value             | Meaning                              |
| ----------------- | ------------------------------------ |
| `false` (default) | Trusts the index (fastest)           |
| `true`            | Re-verifies every hit using analyzer |

**When to use:**

- You manually modify Hive boxes outside the `IndexedBox` (e.g. raw `Hive.box().put()`).
- You suspect rare mismatches after crashes or restores.
- You need absolute correctness over speed.

```dart
final safe = IndexedBox<String, Note>(
  'notes',
  searchableText: (n) => n.content,
  verifyMatches: true, // double-check each match
);
```

---

### `keyComparator` – Custom Result Ordering

**What it does:**
Lets you define a comparator for sorting matched keys before pagination.
By default, `IndexedBox` sorts by `Comparable` key or string order.

```dart
final ordered = IndexedBox<int, User>(
  'users',
  searchableText: (u) => u.name,
  keyComparator: (a, b) => b.compareTo(a), // reverse order
);
```

Useful for:

- Sorting newest IDs first
- Alphabetical vs numerical order
- Deterministic result ordering when keys aren’t `Comparable`

---

### `analyzer` – How Text Is Broken into Tokens

**What it does:**
Defines _how_ each value is tokenized and indexed.  
Three analyzers are built in — pick one based on your search style:

| Analyzer              | Example             | Matches                             |
| --------------------- | ------------------- | ----------------------------------- |
| `TextAnalyzer.basic`  | `"flutter dart"`    | Matches **whole words only**        |
| `TextAnalyzer.prefix` | `"fl" → "flutter"`  | Matches **word prefixes** (default) |
| `TextAnalyzer.ngram`  | `"utt" → "flutter"` | Matches **substrings** anywhere     |

For a detailed explanation, see [**`analyzer`** - How Text Is Broken into Tokens](#-analyzer--how-text-is-broken-into-tokens).

---

### Example: Tuning for Real Apps

#### 🧠 Autocomplete Search

```dart
final box = IndexedBox<String, City>(
  'cities',
  searchableText: (c) => c.name,
  matchAllTokens: false,
  tokenCacheCapacity: 2000,
);
```

- Fast prefix matching (“new yo” → “New York”)
- Low-latency cached results
- Allows partial terms (OR logic)

#### 🔍 Strict Multi-Term Search

```dart
final box = IndexedBox<int, Document>(
  'docs',
  searchableText: (d) => d.content,
  analyzer: Analyzer.basic,
  matchAllTokens: true,
  verifyMatches: true,
);
```

- Each word must appear
- Uses basic analyzer (lightweight)
- Re-verifies for guaranteed correctness

### Summary Table

| Setting              | Type        | Default           | Purpose                                    |
| -------------------- | ----------- | ----------------- | ------------------------------------------ |
| `matchAllTokens`     | `bool`      | `true`            | Require all vs any words to match          |
| `tokenCacheCapacity` | `int`       | `512`             | Speed up repeated searches                 |
| `verifyMatches`      | `bool`      | `false`           | Re-check results for stale index           |
| `keyComparator`      | `Function?` | `null`            | Custom sort for results                    |
| `analyzer`           | `Analyzer`  | `Analyzer.prefix` | How text is tokenized (basic/prefix/ngram) |

---

### 🧩 `analyzer` – How Text Is Broken into Tokens

_[⤴️ Back](#-indexedbox--ultra-fast-full-text-search-for-hive) → IndexedBox_

**What it does:**
Defines _how_ your data is split into tokens and stored in the index.
Every time you `put()` a value, the analyzer breaks its searchable text into tokens — which are then mapped to the keys that contain them.

Later, when you search, the query is tokenized the same way, and any key whose tokens overlap is returned.

You can think of it like this:

```
value -> tokens -> saved in index
query -> tokens -> lookup in index -> matched keys
```

There are three built-in analyzers, each with different speed/flexibility trade-offs:

| Analyzer          | Behavior               | Example Match                | Speed     | Disk Size | Use Case                                |
| ----------------- | ---------------------- | ---------------------------- | --------- | --------- | --------------------------------------- |
| `Analyzer.basic`  | Whole-word search      | `"dart"` → “Learn Dart Fast” | ⚡ Fast   | 🟢 Small  | Exact keyword search                    |
| `Analyzer.prefix` | Word prefix search     | `"flu"` → “Flutter Basics”   | ⚡ Fast   | 🟡 Medium | Autocomplete, suggestions               |
| `Analyzer.ngram`  | Any substring matching | `"utt"` → “Flutter Rocks”    | ⚡ Medium | 🔴 Large  | Fuzzy, partial, or typo-tolerant search |

---

#### 🧱 Basic Analyzer – Whole Words Only (smallest index, fastest writes)

```dart
analyzer: Analyzer.basic,
```

**How it works:**
It only stores _normalized words_ (lowercase, alphanumeric only).

**Example:**

| Value                | Tokens Saved to Index        |
| -------------------- | ---------------------------- |
| `"Flutter and Dart"` | `["flutter", "and", "dart"]` |

**So the index looks like:**

```
flutter → [key1]
and     → [key1]
dart    → [key1]
```

**Search results:**

| Query       | Matching Values         | Why                   |
| ----------- | ----------------------- | --------------------- |
| `"flutter"` | ✅ `"Flutter and Dart"` | full word match       |
| `"flu"`     | ❌                      | prefix not indexed    |
| `"utt"`     | ❌                      | substring not indexed |

> **Use this** if you want fast, strict searches like tags or exact keywords.

---

#### 🔠 Prefix Analyzer – Partial Word Prefixes (great for autocomplete)

```dart
analyzer: Analyzer.prefix,
```

**How it works:**
Each word is split into _all prefixes_ between `minPrefix` and `maxPrefix`.

**Example:**

| Value       | Tokens Saved                                          |
| ----------- | ----------------------------------------------------- |
| `"Flutter"` | `["fl", "flu", "flut", "flutt", "flutte", "flutter"]` |
| `"Dart"`    | `["da", "dar", "dart"]`                               |

**Index snapshot:**

```
fl → [key1]
flu → [key1]
flut → [key1]
...
dart → [key1]
```

**Search results:**

| Query    | Matching Values | Why                       |
| -------- | --------------- | ------------------------- |
| `"fl"`   | ✅ `"Flutter"`  | prefix indexed            |
| `"flu"`  | ✅ `"Flutter"`  | prefix indexed            |
| `"utt"`  | ❌              | substring not at start    |
| `"dart"` | ✅ `"Dart"`     | full word or prefix match |

✅ **Use this** for **autocomplete**, **live search**, or **starts-with** queries.

---

#### 🔍 N-Gram Analyzer – Substrings Anywhere (maximum flexibility)

```dart
analyzer: Analyzer.ngram,
```

**How it works:**
Creates _all possible substrings_ (“n-grams”) between `minN` and `maxN` for every word.

**Example:**

| Value       | Tokens Saved (simplified)                                                                                      |
| ----------- | -------------------------------------------------------------------------------------------------------------- |
| `"Flutter"` | `["fl", "lu", "ut", "tt", "te", "er", "flu", "lut", "utt", "tte", "ter", "flut", "lutt", "utte", "tter", ...]` |

_(for each length n = 2→6)_

**Index snapshot (simplified):**

```
fl  → [key1]
lu  → [key1]
utt → [key1]
ter → [key1]
...
```

**Search results:**

| Query   | Matching Values | Why                   |
| ------- | --------------- | --------------------- |
| `"fl"`  | ✅ `"Flutter"`  | substring indexed     |
| `"utt"` | ✅ `"Flutter"`  | substring indexed     |
| `"tte"` | ✅ `"Flutter"`  | substring indexed     |
| `"zzz"` | ❌              | substring not present |

⚠️ **Trade-off:**

- Slower writes (`≈2–4×`)
- More index data (`≈2–6× larger`)
- But _can match anywhere in the text_ — ideal for **fuzzy**, **partial**, or **typo-tolerant** search.

> **Use this** if you want “contains” behavior (`"utt"` → `"Flutter"`), not just prefixes.

## ⚖️ Choosing the Right Analyzer

| If you want...        | Use                                    | Example                       |
| --------------------- | -------------------------------------- | ----------------------------- |
| Exact keyword search  | `Analyzer.basic`                       | Searching “tag” or “category” |
| Fast autocomplete     | `Analyzer.prefix`                      | Typing “fl” → “Flutter”       |
| “Contains” matching   | `Analyzer.ngram`                       | Searching “utt” → “Flutter”   |
| Fuzzy/tolerant search | `Analyzer.ngram` (with larger n range) | “fluttr” → “Flutter”          |

## 🧩 Quick Recap (All Analyzers Side-by-Side)

| Value: `"Flutter and Dart"` | Basic                      | Prefix (min=2,max=9)                                                     | N-Gram (min=2,max=6)                                                        |
| --------------------------- | -------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| Tokens                      | [`flutter`, `and`, `dart`] | [`fl`, `flu`, `flut`, `flutt`, `flutte`, `flutter`, `da`, `dar`, `dart`] | [`fl`, `lu`, `ut`, `tt`, `te`, `er`, `flu`, `lut`, `utt`, `tte`, `ter`,...] |
| Query `"flu"`               | ❌                         | ✅                                                                       | ✅                                                                          |
| Query `"utt"`               | ❌                         | ❌                                                                       | ✅                                                                          |
| Query `"dart"`              | ✅                         | ✅                                                                       | ✅                                                                          |

---

# Clean Architecture with `Hivez`

_[⤴️ Back](#table-of-contents) → Table of Contents_

A major strength of `Hivez` is how it **fits seamlessly into Clean Architecture**. Unlike raw Hive, where each box type (`Box`, `LazyBox`, `IsolatedBox`, etc.) exposes different APIs, all `Hivez` boxes share the **same parent interface**:

```dart
abstract class BoxInterface<K, T> { ... }
```

Every `HivezBox` variant (`HivezBox`, `HivezBoxLazy`, `HivezBoxIsolated`, `HivezBoxIsolatedLazy`) inherits this interface, which defines **35+ functions and getters**, all tested and production-grade.

This makes your persistence layer **consistent, testable, and replaceable** — essential principles of Clean Architecture.

### Why this matters

- **Dependency Inversion**: Higher layers depend only on the abstract `BoxInterface`, not on Hive’s raw implementation.
- **Interchangeable Implementations**: Swap `HivezBox` ↔ `HivezBoxLazy` ↔ `HivezBoxIsolated` with a one-line change, without breaking your repository or use cases.
- **Consistency**: All boxes expose the same async-safe, type-safe API. No branching logic depending on box type.
- **Testability**: You can mock or fake `BoxInterface` in unit tests easily.
- **Future-proof**: Scaling from a simple `Box` to an `IsolatedBox` in production requires no changes in your business logic.

### Example: Clean Architecture Repository

With raw Hive:

```dart
class UserRepository {
  final Box _box;

  UserRepository(this._box);

  Future<User?> getUser(int id) async {
    return _box.get(id) as User?;
  }
}
```

Problems:

- `Box` ties your repository to Hive’s low-level API
- Type safety is weak (`dynamic` everywhere)
- Changing to `LazyBox` breaks this class

With Hivez:

```dart
class UserRepository {
  final BoxInterface<int, User> _box;

  UserRepository(this._box);

  Future<User?> getUser(int id) => _box.get(id);
}
```

Advantages:

- `BoxInterface<int, User>` guarantees type safety
- Repository is **decoupled** from the persistence detail
- Can inject any `HivezBox` variant (regular, lazy, isolated) without changing logic
- Perfectly aligns with **dependency inversion** in Clean Architecture

### In Practice

- Define repositories and services against `BoxInterface<K, T>`
- Swap implementations (`HivezBox`, `HivezBoxLazy`, etc.) depending on environment
- Unit test with a mock `BoxInterface` — no Hive needed in tests

> In short: **Hivez enforces Clean Architecture by design**.
> All boxes inherit from a single, production-ready `BoxInterface` with 35+ consistent, type-safe methods — so you can build scalable, testable, and maintainable apps without worrying about low-level Hive details.

# ❓ FAQ / Common Pitfalls

_[⤴️ Back](#table-of-contents) → Table of Contents_

#### Do I still need to call `Hive.openBox`?

**No.** All `HivezBox` types auto-initialize on first use with `ensureInitialized()`.  
You don’t need to worry about `Hive.isBoxOpen` checks or manual setup.

#### Does Hivez replace Hive?

**No.** Hivez is a **safe wrapper** around [`hive_ce`](https://pub.dev/packages/hive_ce).  
You still use Hive adapters, types, and storage — Hivez just enforces **type safety**, **clean architecture**, and **concurrency safety**.

#### What’s the difference between `HivezBox`, `Lazy`, and `Isolated`?

- `HivezBox` → Default, fast in-memory reads + async writes
- `HivezBoxLazy` → Loads values on-demand, better for **large datasets**
- `HivezBoxIsolated` → Safe across isolates, for **background workers**
- `HivezBoxIsolatedLazy` → Combines isolate safety + lazy loading

All share the **same API** (`BoxInterface` with 35+ methods), so you can swap them with a single line.

#### Do I still need to register adapters?

**Yes.** Hive always requires `TypeAdapter`s for custom objects and enums.  
Hivez does not remove this requirement, but provides [a quick setup guide](#-setup-guide-for-hive_ce).

#### Is it concurrency-safe?

**Yes.** All writes use internal locks, ensuring atomicity. Reads are async-safe.  
You can safely call multiple operations in parallel without corrupting data.

#### Can I use Hivez in unit tests?

**Yes.** Since every box implements the same `BoxInterface<K, T>`, you can:

- inject a real `HivezBox`
- or mock/fake the interface for fast, Hive-free tests

#### When should I use isolated boxes?

- Heavy background isolates (e.g., parsing, sync engines)
- Multi-isolate apps where multiple isolates may open the same box  
  If you’re not familiar with isolate setup, stick to `HivezBox` or `HivezBoxLazy`.

#### Do lazy boxes support `values` like normal boxes?

No. Lazy boxes only load values **on demand**.  
Use `getAllValues()` instead — Hivez implements this for you safely.

### Can I migrate between box types later?

**Yes.** Since all boxes share the same API, changing from:

```dart
final box = HivezBox<int, User>('users');
```

to

```dart
final box = HivezBoxIsolated<int, User>('users');
```

is a **single-line change**, with no code breakage.
Here’s the added paragraph for adapter troubleshooting:

#### How do I troubleshoot errors when generating adapters?

If you get errors while running `build_runner` (for example, after adding a new model), double-check that **all the models and enums you want adapters for are included in your `hive_adapters.dart` file**.  
If something still doesn’t work, try deleting the previously generated files (`.g.dart`, `.g.yaml`) and re-running:

```sh
dart run build_runner build --delete-conflicting-outputs
```

This forces Hive CE to regenerate fresh adapters for all the registered types.

#### What if I run into other Hive-related issues?

If you encounter a bug or limitation that comes from Hive itself, please note that Hivez is only a **wrapper around [`hive_ce`](https://pub.dev/packages/hive_ce)**.  
That means such issues can’t be solved in Hivez. For those cases, head over to the [hive_ce repository](https://github.com/isar/hive), it’s actively maintained, very stable, and the right place for core Hive questions or bug reports.

# Performance & Safety

_[⤴️ Back](#table-of-contents) → Table of Contents_

One of the core design goals of **Hivez** is to stay **as fast as raw Hive**, while adding safety, type guarantees, and architectural consistency.

### Practically Zero Overhead

Although all boxes in Hivez share the same `BoxInterface`, there are **no runtime type checks on each operation**.  
Every method call is compiled down to direct Hive operations — engineered to be as **fast, easy, and safe** as possible.

- **No overhead on reads/writes** — same performance as Hive CE
- **Hundreds of tests** across all 35+ methods and box types ensure production safety
- **Engineered concurrency** — built-in locks guarantee atomic writes and safe reads

### Enforced Type Safety

Raw Hive exposes `dynamic` APIs, which can lead to runtime type errors.  
Hivez enforces **compile-time safety** for both keys and values:

```dart
// Hivez: compile-time type safety
final users = HivezBox<int, User>('users');
await users.put(1, User('Alice'));   // ✅ Valid
await users.put('wrongKey', 'test'); // ❌ Compile error
```

This prevents silent data corruption and eliminates the need for manual casting.

### Safe Switching Between Box Types

In Hive, switching between `Box`, `LazyBox`, or `IsolatedBox` often **breaks your code** because each exposes different APIs.

```dart
Box<User> box = await Hive.openBox<User>('users');
LazyBox<User> lazy = await Hive.openLazyBox<User>('users');
// ❌ LazyBox doesn't have the same API as Box
```

With Hivez, all boxes (`HivezBox`, `HivezBoxLazy`, `HivezBoxIsolated`, `HivezBoxIsolatedLazy`) share the **same API**:

```dart
BoxInterface<int, User> box = HivezBox<int, User>('users');
BoxInterface<int, User> box = HivezBoxLazy<int, User>('users');
```

Your repositories and services remain untouched — a **single-line change** swaps the underlying storage strategy.

> In short: **Hivez delivers Hive performance with added guarantees** — zero runtime overhead, full type safety, safe concurrency, and seamless box switching — all tested and ready for production.

# Why `Hivez`?

_[⤴️ Back](#table-of-contents) → Table of Contents_

Over the years, while building projects both large and small, I noticed a recurring pattern: every time I reached for Hive, I ended up writing the same wrapper code to make it safer, more predictable, and easier to use.

Hive is fast and lightweight, but out-of-the-box it comes with challenges:

- **Initialization boilerplate** – You always need to call `openBox` and check if the box is open.
- **Type safety gaps** – By default, Hive uses `dynamic`, leaving room for runtime errors.
- **Inconsistent APIs** – `Box`, `LazyBox`, and `IsolatedBox` all have slightly different behaviors.
- **Concurrency risks** – Without locks, concurrent writes can corrupt data.
- **Limited tooling** – You only get basic CRUD; features like backup, search, or iteration helpers are missing.

For every new project, I found myself solving the same problems in the same way:

- Add **type parameters** to enforce compile-time guarantees.
- Write **synchronized access** to prevent corruption.
- Create **utility extensions** for backup, restore, and search.
- Wrap Hive APIs in a **cleaner interface** to fit Clean Architecture principles.

That’s when I decided to create Hivez: instead of repeating this codebase after codebase, I could create a **production-ready wrapper** that solves these problems once — not just for me, but for the community.

### What makes Hivez different?

Hivez is not just a thin wrapper; it’s a **designed architecture layer** on top of Hive CE:

- **Unified API across all box types**
  Every box — `HivezBox`, `HivezBoxLazy`, `HivezBoxIsolated`, `HivezBoxIsolatedLazy` — inherits from the same parent, **`BoxInterface`**.
  That means **35+ functions and getters** are guaranteed, tested, and production-grade.

- **Type safety, enforced**
  No more `dynamic` or runtime casting:

  ```dart
  final users = HivezBox<int, User>('users');
  await users.put(1, User('Alice'));
  final u = await users.get(1); // returns User, not dynamic
  ```

- **Zero setup required**
  No more boilerplate `openBox`. Each Hivez box automatically initializes on first use:

  ```dart
  final settings = HivezBox<String, bool>('settings');
  await settings.put('darkMode', true);
  ```

- **Clean Architecture, by design**
  Because every box implements the same interface, your repositories and services depend only on **`BoxInterface<K, T>`**, not Hive internals. That makes your code more modular, testable, and future-proof.

- **Utility-rich**
  Out of the box, you get:

  - Backup/restore (JSON or compressed binary)
  - Full-text search with pagination
  - Iteration helpers (`foreachKey`, `foreachValue`)
  - Safe compaction and flushing
  - Concurrency locks for atomic operations

### Why this matters in real projects

When deadlines are tight and projects grow, you don’t want to debug concurrency issues, write boilerplate initialization code, or figure out how to migrate from a `Box` to a `LazyBox`.

With Hivez:

- Switching between box types is a **one-line change**.
- Your persistence layer always has **the same reliable API**.
- Your business logic is **shielded from Hive’s low-level quirks**.
- You can safely scale from small apps to production-grade systems without rewriting storage code.

**Hivez was born out of necessity** — the necessity to write less boilerplate, avoid bugs, and follow best practices without fighting the storage layer.

# 📦 More `jozz` Packages

_[⤴️ Back](#table-of-contents) → Table of Contents_

I’m Jozz — and my packages share a simple philosophy: **developer experience first**.
I try to avoid boilerplate wherever possible, and most of these packages were born out of real needs in my own projects. Each one comes with clear documentation, minimal setup, and APIs that are easy to pick up without surprises.

They’re built to be lightweight, reliable, and ready for production, always with simplicity in mind. There are more packages in the works, following the same approach.
If you find them useful and feel like supporting, you’re welcome to do so (:

<p>
  <a href="https://buymeacoffee.com/yosefd99v" target="https://buymeacoffee.com/yosefd99v">
    ☕ Buy me a coffee
  </a>
</p>

- [shrink](#-shrink--compress-anything-in-one-line) – Compress Anything in One Line
- [track](#-track--persistent-streaks-counters--records) – Persistent Streaks, Counters & Records
- [prf](#-prf--sharedpreferences-without-the-pain) – SharedPreferences, Without the Pain
- [time_plus](#-time_plus--smarter-datetime--duration-extensions) – Smarter DateTime & Duration Extensions
- [exui](#-exui--supercharge-your-flutter-ui) – Supercharge Your Flutter UI
- [limit](#-limit--cooldowns--rate-limits-simplified) – Cooldowns & Rate Limits, Simplified
- [jozz_events](#-jozz_events--strongly-typed-events-for-clean-architecture) – Strongly-Typed Events for Clean Architecture

### 🔽 [shrink](https://pub.dev/packages/shrink) – Compress Anything in One Line

Because every byte counts. `shrink` makes data compression effortless with a **one-line API** and fully lossless results. It auto-detects the best method, often cutting size by **5× to 40×** (and up to **1,000×+** for structured data). Perfect for **Firestore, local storage, or bandwidth-sensitive apps**. Backed by clear docs and real-world benchmarks.

### 📊 [track](https://pub.dev/packages/track) – Persistent Streaks, Counters & Records

Define once, track forever. `track` gives you plug-and-play tools for **streaks, counters, activity logs, and records** — all persisted safely across sessions and isolates. From **daily streaks** to **rolling counters** to **best-ever records**, it handles resets, history, and storage automatically. Clean APIs, zero boilerplate, and deeply detailed documentation.

### ⚡ [prf](https://pub.dev/packages/prf) – SharedPreferences, Without the Pain

No strings, no boilerplate, no setup. `prf` lets you define variables once, then `get()` and `set()` them anywhere with a **type-safe API**. It fully replaces raw `SharedPreferences` with support for **20+ built-in types** (including `DateTime`, `Duration`, `Uint8List`, JSON, and enums). Every variable is cached, test-friendly, and isolate-safe with a `.isolated` mode. Designed for **clarity, scale, and zero friction**, with docs that make local persistence finally headache-free.

### ⏱ [time_plus](https://pub.dev/packages/time_plus) – Smarter DateTime & Duration Extensions

Stop wrestling with `DateTime` and `Duration`. `time_plus` adds the missing tools you wish Dart had built in: **add and subtract time units**, **start/end of day/week/month**, **compare by precision**, **yesterday/tomorrow**, **fractional durations**, and more. Built with **128+ extensions**, **700+ tests**, and **zero dependencies**, it’s faster, more precise, and more reliable than the classic `time` package — while keeping APIs clear and intuitive. Ideal for **scheduling, analytics, or any app where every microsecond counts**.

### 🎨 [exui](https://pub.dev/packages/exui) – Supercharge Your Flutter UI

Everything your widgets wish they had. `exui` is a **zero-dependency extension library** for Flutter with **200+ chainable utilities** for padding, margin, centering, gaps, visibility, constraints, gestures, buttons, text styling, and more — all while keeping your widget tree fully native.

No wrappers. No boilerplate. Just concise, expressive methods that feel built into Flutter itself. Backed by **hundreds of unit tests** and **exceptional documentation**, `exui` makes UI code cleaner, faster, and easier to maintain.

### ⏲ [limit](https://pub.dev/packages/limit) – Cooldowns & Rate Limits, Simplified

One line. No boilerplate. No setup. `limit` gives you **persistent cooldowns** and **token-bucket rate limiting** across sessions, isolates, and restarts. Perfect for **daily rewards**, **retry delays**, **API quotas**, or **chat limits**. Define once, automate forever — the system handles the timing, persistence, and safety behind the scenes. Clear docs and practical examples included.

### 📢 [jozz_events](https://pub.dev/packages/jozz_events) – Strongly-Typed Events for Clean Architecture

A **domain-first, framework-agnostic event bus** built for scalable apps. `jozz_events` enables **decoupled, strongly-typed communication** between features and layers — without the spaghetti. It’s lightweight, dependency-free, lifecycle-aware, and integrates naturally with **Clean Architecture**. Ideal for Flutter or pure Dart projects where modularity, testability, and clarity matter most.

## 🔗 License MIT © Jozz

<p align="center">
  <a href="https://buymeacoffee.com/yosefd99v" target="https://buymeacoffee.com/yosefd99v">
    ☕ Enjoying this package? You can support it here (:
  </a>
</p>
