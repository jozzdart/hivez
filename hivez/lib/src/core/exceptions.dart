part of 'core.dart';

/// {@template box_not_initialized_exception}
/// Exception thrown when a Hivez box is accessed before it has been properly initialized.
///
/// This exception is typically thrown by Hivez box implementations when an operation
/// is attempted on a box that has not yet been opened or initialized via [ensureInitialized].
///
/// For example, attempting to read, write, or perform any operation on a box before
/// calling `ensureInitialized()` will result in this exception being thrown. This is a
/// safeguard to prevent undefined behavior or data corruption due to uninitialized state.
///
/// Example usage:
/// ```dart
/// final box = HivezBox<String, MyModel>('myBox');
/// // Forgetting to call await box.ensureInitialized();
/// try {
///   final value = await box.get('key');
/// } on BoxNotInitializedException catch (e) {
///   print(e); // HivezBoxInitException: Box not initialized. Call ensureInitialized() first.
/// }
/// ```
///
/// {@endtemplate}
class BoxNotInitializedException extends HivezBoxException {
  BoxNotInitializedException(
      {required super.boxName, super.cause, super.stackTrace})
      : super(message: 'Box not initialized. Call ensureInitialized() first.');
}

class InvalidAddOperationException<K> extends HivezBoxException {
  InvalidAddOperationException(
      {required super.boxName, super.cause, super.stackTrace})
      : super(
            message: 'Cannot use add() on a box with non-int keys (K = $K). '
                'Use put(key, value) instead.');
}

class InvalidAddAllOperationException<K> extends HivezBoxException {
  InvalidAddAllOperationException(
      {required super.boxName, super.cause, super.stackTrace})
      : super(
            message:
                'Cannot use addAll() on a box with non-int keys (K = $K).');
}
