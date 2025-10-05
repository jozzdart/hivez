import 'package:hivez/src/exceptions/exceptions.dart';
import 'package:meta/meta.dart';

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
@internal
class BoxNotInitializedException extends HivezBoxException {
  /// Creates a new [BoxNotInitializedException] with the provided [message].
  ///
  /// The [message] should describe the context or reason for the exception.
  BoxNotInitializedException(
      {required super.boxName, super.cause, super.stackTrace})
      : super(message: 'Box not initialized. Call ensureInitialized() first.');
}
