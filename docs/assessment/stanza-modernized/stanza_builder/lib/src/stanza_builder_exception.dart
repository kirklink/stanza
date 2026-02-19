class StanzaBuilderException implements Exception {
  final String cause;
  StanzaBuilderException(this.cause);

  @override
  String toString() => 'StanzaBuilderException: $cause';
}
