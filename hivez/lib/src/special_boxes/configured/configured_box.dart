library;

import 'dart:async';

import 'package:meta/meta.dart' show internal;
import 'package:synchronized/synchronized.dart' show Lock;

import 'package:hivez/src/boxes/boxes.dart';
import 'package:hivez/src/builders/builders.dart';

part 'extensions.dart';
part 'shared_lock.dart';
part 'wrapped_operation.dart';

/// {@template configured_box}
/// A [BoxDecorator] that creates and wraps a box instance from a [BoxConfig].
///
/// This class provides a convenient way to instantiate a box
/// with a given configuration, abstracting away the details of box creation.
/// It is especially useful for scenarios where you want to easily construct
/// a box with custom settings (such as encryption, storage backend, or
/// serialization options) using a [BoxConfig] object.
///
/// Example usage:
/// ```dart
/// final config = BoxConfig(
///   name: 'myBox',
///   // ...other configuration options
/// );
/// final box = ConfiguredBox<String, MyModel>(config);
/// await box.ensureInitialized();
/// await box.put('key', MyModel(...));
/// ```
///
/// The [ConfiguredBox] delegates all operations to the underlying box created
/// by [BoxConfig.createBox], while exposing the [config] for reference.
/// {@endtemplate}
class ConfiguredBox<K, T> extends BoxDecorator<K, T> {
  /// The configuration used to create the underlying box.
  final BoxConfig config;

  /// Creates a [ConfiguredBox] by instantiating a box from the given [config].
  ///
  /// The [config] is used to create the actual box instance via [BoxConfig.createBox].
  ConfiguredBox(
    this.config,
  ) : super(config.createBox<K, T>());
}
