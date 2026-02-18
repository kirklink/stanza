class StanzaException implements Exception {
  final String cause;
  StanzaException(this.cause);

  @override
  String toString() => 'StanzaException: $cause';
}
