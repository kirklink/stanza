/// Interface for query clauses.
abstract class QueryClause {
  String get clause;
  QueryClause clone();
}