import 'package:stanza/src/query_clause.dart';

class LimitClause implements QueryClause {
  final int limit;

  LimitClause(this.limit);

  String get clause => 'LIMIT ${limit.toString()}';

  LimitClause clone() {
    return this;
  }
}
