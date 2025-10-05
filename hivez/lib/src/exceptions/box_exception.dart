import 'package:hivez/src/exceptions/exceptions.dart';

/// Thrown for general box-level issues (I/O, locking, corruption, etc.)
class HivezBoxException extends HivezException {
  const HivezBoxException({
    required String boxName,
    required String message,
    super.cause,
    super.stackTrace,
  }) : super('[BOX: $boxName] $message');
}
