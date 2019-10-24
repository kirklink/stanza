
class StanzaException implements Exception {
  String cause;
  StanzaException(this.cause);

  String toString() => cause;
}