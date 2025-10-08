library;

import 'dart:async';

import 'package:meta/meta.dart' show internal;
import 'package:synchronized/synchronized.dart' show Lock;

import 'package:hivez/src/boxes/boxes.dart';
import 'package:hivez/src/builders/builders.dart';

part 'extensions.dart';
part 'shared_lock.dart';
part 'wrapped_operation.dart';

class ConfiguredBox<K, T> extends BoxDecorator<K, T> {
  final BoxConfig config;

  ConfiguredBox(
    this.config,
  ) : super(config.createBox<K, T>());
}
