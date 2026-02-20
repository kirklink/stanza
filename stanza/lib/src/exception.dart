/// Exception thrown by Stanza operations.
///
/// Wraps PostgreSQL driver errors and query validation failures.
class StanzaException implements Exception {
  /// A human-readable description of what went wrong.
  final String message;

  /// The underlying exception, if any (typically a `PgException`).
  final Object? cause;

  const StanzaException(this.message, {this.cause});

  @override
  String toString() => cause != null
      ? 'StanzaException: $message (caused by: $cause)'
      : 'StanzaException: $message';
}
