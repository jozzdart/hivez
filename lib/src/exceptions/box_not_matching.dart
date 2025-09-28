class BoxNotMatchingException implements Exception {
  final String message;
  BoxNotMatchingException(this.message);

  @override
  String toString() => 'BoxNotMatchingException: $message';
}
