
class QueryException implements Exception {
  String cause;
  QueryException(this.cause);

  String toString() => cause;
}