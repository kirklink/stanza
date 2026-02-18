import 'package:stanza/src/query_clause.dart';

class OffsetClause implements QueryClause {
  final int offset;

  OffsetClause(this.offset);

  @override
  String get clause => 'OFFSET $offset';

  @override
  OffsetClause clone() => this;
}
