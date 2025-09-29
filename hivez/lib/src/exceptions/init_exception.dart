import 'package:meta/meta.dart';

@internal
class BoxNotInitializedException implements Exception {
  final String message;
  BoxNotInitializedException(this.message);

  @override
  String toString() => 'HivezBoxInitException: $message';
}
