class HivezBoxInvalidTypeException implements Exception {
  final String message;
  HivezBoxInvalidTypeException(this.message);
  @override
  String toString() => 'HivezBoxInvalidTypeException: $message';
}
