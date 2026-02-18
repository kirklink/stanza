import 'package:stanza/src/query_clause.dart';

class LimitClause implements QueryClause {
  final int limit;

  LimitClause(this.limit);

  @override
  String get clause => 'LIMIT $limit';

  @override
  LimitClause clone() => this;
}
