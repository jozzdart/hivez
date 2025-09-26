class HiveServiceInitException implements Exception {
  final String message;
  HiveServiceInitException(this.message);

  @override
  String toString() => 'HiveServiceInitException: $message';
}
