import 'package:stanza/src/query_clause.dart';


class OffsetClause implements QueryClause {

  final int offset;

  OffsetClause(this.offset);

  String get clause => 'OFFSET ${offset.toString()}';

  OffsetClause clone() {
    return this;
  }

}