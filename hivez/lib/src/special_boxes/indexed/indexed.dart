import 'package:hive_ce/hive.dart';
import 'package:hivez/src/boxes/boxes.dart';
import 'package:hivez/src/builders/builders.dart';
import 'package:hivez/src/exceptions/box_exception.dart';
import 'package:hivez/src/special_boxes/configured/configured_box.dart';

part 'engine.dart';
part 'journal.dart';
part 'cache.dart';
part 'search.dart';
part 'analyzer.dart';
part 'extensions.dart';
part 'exceptions.dart';
part 'lock.dart';

class IndexedBox<K, T> extends ConfiguredBox<K, T> {
  final IndexEngine<K, T> _engine;
  final IndexJournal _journal;
  final TokenKeyCache<K> _cache;
  late final IndexedBoxLocker _lock;
  late final IndexSearcher<K, T> _searcher;

  IndexedBox(
    super.config, {
    required String Function(T) searchableText,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
    TextAnalyzer<T>? analyzer,
  })  : _engine = IndexEngine<K, T>(
          config.copyWith(name: '${config.name}__idx', logger: null),
          analyzer: analyzer ?? PrefixTextAnalyzer<T>(searchableText),
          matchAllTokens: matchAllTokens,
        ),
        _journal = BoxIndexJournal(
          config.copyWith(name: '${config.name}__idx_meta', logger: null),
        ),
        _cache = tokenCacheCapacity <= 0
            ? NoopTokenKeyCache<K>()
            : LruTokenKeyCache<K>(tokenCacheCapacity.clamp(1, 10000)) {
    _searcher = IndexSearcher<K, T>(
      engine: _engine,
      cache: _cache,
      analyzer: analyzer ?? PrefixTextAnalyzer<T>(searchableText),
      verifyMatches: verifyMatches,
      ensureReady: ensureInitialized,
      getValue: super.get,
    );
    _lock = IndexedBoxLocker(this);
  }

  factory IndexedBox.create(
    String name, {
    BoxType type = BoxType.regular,
    required String Function(T) searchableText,
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
    String? path,
    String? collection,
    LogHandler? logger,
    TextAnalyzer<T>? analyzer,
    bool matchAllTokens = true,
    int tokenCacheCapacity = 512,
    bool verifyMatches = false,
    int Function(K a, K b)? keyComparator,
  }) =>
      IndexedBox<K, T>(
        BoxConfig(
          name,
          type: type,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          logger: logger,
        ),
        searchableText: searchableText,
        analyzer: analyzer,
        matchAllTokens: matchAllTokens,
        tokenCacheCapacity: tokenCacheCapacity,
        verifyMatches: verifyMatches,
        keyComparator: keyComparator,
      );

  // -----------------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------------

  @override
  bool get isInitialized =>
      super.isInitialized && _engine.isInitialized && _journal.isInitialized;

  @override
  Future<void> ensureInitialized() async {
    await _engine.ensureInitialized(); // index box
    await _journal.ensureInitialized(); // meta/journal
    await super.ensureInitialized(); // main box

    if (await _journal.isDirty()) {
      config.logger?.call('Dirty flag detected → rebuilding index');
      try {
        await rebuildIndex();
      } catch (e, st) {
        throw IndexRebuildFailed(boxName: name, cause: e, stackTrace: st);
      }
    }
  }

  // -----------------------------------------------------------------------------
  // Disk / Close / Flush / Compact  (non-mutating; no dirty toggles)
  // -----------------------------------------------------------------------------
  @override
  Future<void> flushBox() async {
    await _lock.operation("FLUSH_BOX").run(() async {
      await _engine.flushBox();
      await _journal.flushBox();
      await super.flushBox();
    });
  }

  @override
  Future<void> compactBox() async {
    await _lock.operation("COMPACT_BOX").run(() async {
      await _engine.compactBox();
      await _journal.compactBox();
      await super.compactBox();
    });
  }

  @override
  Future<void> closeBox() async {
    await _lock.operation("CLOSE_BOX").run(() async {
      await _engine.flushBox();
      await _journal.flushBox();
      await super.flushBox();
      _cache.clear();
      await _engine.closeBox();
      await _journal.closeBox();
      await super.closeBox();
    });
  }

  @override
  Future<void> deleteFromDisk() async {
    await _lock.operation("DELETE_FROM_DISK").run(() async {
      _cache.clear();
      await _engine.deleteFromDisk();
      await _journal.deleteFromDisk();
      await super.deleteFromDisk();
    });
  }

  /// Clears runtime caches + resets journal (no persistent data loss).
  Future<void> resetRuntimeState() async {
    await _lock.operation("RESET_RUNTIME_STATE").run(() async {
      _cache.clear();
      await _journal.reset();
    });
  }

  @override
  Future<int> estimateSizeBytes() async {
    final size = await super.estimateSizeBytes();
    final engineSize = await _engine.estimateSizeBytes();
    final journalSize = await _journal.estimateSizeBytes();
    return size + engineSize + journalSize;
  }

  // -----------------------------------------------------------------------------
  // Write path (all wrapped in _writeTxn)
  // -----------------------------------------------------------------------------
  @override
  Future<void> put(K key, T value) => _lock.operation("PUT").run(() async {
        final old = await super.get(key);
        await super.put(key, value);
        await _engine.onPut(key, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
      });

  @override
  Future<void> putAll(Map<K, T> entries) {
    if (entries.isEmpty) return Future.value();
    return _lock.operation("PUT_ALL").run(() async {
      final olds = <K, T>{};
      for (final e in entries.entries) {
        final v = await super.get(e.key);
        if (v != null) olds[e.key] = v;
      }
      await super.putAll(entries);
      await _engine.onPutMany(entries, olds: olds);
      for (final v in olds.values) {
        _invalidateTokensFor(v);
      }
      for (final v in entries.values) {
        _invalidateTokensFor(v);
      }
    });
  }

  @override
  Future<int> add(T value) => _lock.operation("ADD").run(() async {
        final id = await super.add(value);
        await _engine.onPut(id as K, value);
        _invalidateTokensFor(value);
        return id;
      });

  @override
  Future<void> addAll(Iterable<T> values) {
    if (values.isEmpty) return Future.value();
    return _lock.operation("ADD_ALL").run(() async {
      final news = <K, T>{};
      for (final v in values) {
        final id = await super.add(v);
        news[id as K] = v;
        _invalidateTokensFor(v);
      }
      await _engine.onPutMany(news);
    });
  }

  @override
  Future<void> delete(K key) => _lock.operation("DELETE").run(() async {
        final old = await super.get(key);
        await super.delete(key);
        if (old != null) {
          await _engine.onDelete(key, oldValue: old);
          _invalidateTokensFor(old);
        }
      });

  @override
  Future<void> deleteAll(Iterable<K> keys) {
    final unique = keys is Set<K> ? keys : keys.toSet();
    if (unique.isEmpty) return Future.value();
    return _lock.operation("DELETE_ALL").run(() async {
      final olds = <K, T>{};
      for (final k in unique) {
        final v = await super.get(k);
        if (v != null) olds[k] = v;
      }
      await super.deleteAll(unique);
      if (olds.isNotEmpty) {
        await _engine.onDeleteMany(olds);
        for (final v in olds.values) {
          _invalidateTokensFor(v);
        }
      }
    });
  }

  @override
  Future<void> deleteAt(int index) =>
      _lock.operation("DELETE_AT").run(() async {
        final k = await super.keyAt(index);
        final old = await super.get(k);
        await super.deleteAt(index);
        if (old != null) {
          await _engine.onDelete(k, oldValue: old);
          _invalidateTokensFor(old);
        }
      });

  @override
  Future<void> clear() => _lock.operation("CLEAR").run(() async {
        await super.clear();
        await _engine.clear();
        _cache.clear();
      });

  @override
  Future<void> putAt(int index, T value) =>
      _lock.operation("PUT_AT").run(() async {
        final k = await super.keyAt(index);
        final old = await super.get(k);
        await super.putAt(index, value);
        await _engine.onPut(k, value, oldValue: old);
        _invalidateTokensFor(old);
        _invalidateTokensFor(value);
      });

  @override
  Future<bool> moveKey(K oldKey, K newKey) =>
      _lock.operation("MOVE_KEY").run(() async {
        final v = await super.get(oldKey);
        if (v == null) return false;
        final moved = await super.moveKey(oldKey, newKey);
        if (moved) {
          await _engine.onDelete(oldKey, oldValue: v);
          await _engine.onPut(newKey, v);
          _invalidateTokensFor(v);
        }
        return moved;
      });

  // Values
  Future<List<T>> search(String query, {int? limit, int offset = 0}) =>
      _searcher.values(query, limit: limit, offset: offset);

  // Keys
  Future<List<K>> searchKeys(String query, {int? limit, int offset = 0}) =>
      _searcher.keys(query, limit: limit, offset: offset);

  // Streams
  Stream<K> searchKeysStream(String query) => _searcher.keysStream(query);
  Stream<T> searchStream(String query) => _searcher.valuesStream(query);

  // -----------------------------------------------------------------------------
  // Rebuild index (journaled)
  // -----------------------------------------------------------------------------
  Future<void> rebuildIndex({void Function(double progress)? onProgress}) =>
      _lock.operation("REBUILD_INDEX").run(() async {
        await _engine.clear();
        _cache.clear();

        final total = await length;
        var processed = 0;
        const chunk = 500;
        final buffer = <String, Set<K>>{};

        Future<void> flush() async {
          if (buffer.isEmpty) return;
          final payload = <String, List<K>>{};
          buffer.forEach((token, set) {
            if (set.isNotEmpty) payload[token] = set.toList(growable: false);
          });
          if (payload.isNotEmpty) await _engine.putAll(payload);
          buffer.clear();
        }

        await foreachValue((k, v) async {
          for (final t in _analyze(v)) {
            (buffer[t] ??= <K>{}).add(k);
          }
          processed++;
          if (processed % chunk == 0) {
            await flush();
            onProgress?.call(total == 0 ? 1.0 : processed / total);
            await Future<void>.delayed(Duration.zero);
          }
        });

        await flush();
        onProgress?.call(1.0);
      });

  // -----------------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------------
  Iterable<String> _analyze(T v) => _engine.analyzer.analyze(v);

  void _invalidateTokensFor(T? value) {
    if (value == null) return;
    _cache.invalidateTokens(_analyze(value));
  }

  @override
  bool operator ==(Object other) =>
      other is IndexedBox<K, T> &&
      other._engine == _engine &&
      other._journal == _journal &&
      other._cache == _cache &&
      config.name == other.config.name;

  @override
  int get hashCode =>
      _engine.hashCode ^ _journal.hashCode ^ _cache.hashCode ^ super.hashCode;

  @override
  String toString() =>
      '${super.toString()} <[ engine: $_engine, journal: $_journal, cache: $_cache ]>';
}
