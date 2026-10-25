/// Raised when bundled JSON content is malformed or inconsistent.
class ContentException implements Exception {
  ContentException(this.message);

  final String message;

  @override
  String toString() => 'ContentException: $message';
}
