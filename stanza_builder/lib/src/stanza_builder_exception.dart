
class StanzaBuilderException implements Exception {
  String cause;
  StanzaBuilderException(this.cause);

  String toString() => cause;
}