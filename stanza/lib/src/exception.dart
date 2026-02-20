/// Exception thrown by Stanza operations.
class StanzaException implements Exception {
  final String message;
  final Object? cause;

  const StanzaException(this.message, {this.cause});

  @override
  String toString() => cause != null
      ? 'StanzaException: $message (caused by: $cause)'
      : 'StanzaException: $message';
}
