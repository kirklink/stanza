import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/shared/where_operations.dart';
import 'package:stanza/src/shared/where_package.dart';

class HavingClauseCloner {
  final List<String> clauses;
  HavingClauseCloner(this.clauses);
}

mixin HavingClause on Query {
  List<String> _havingClauses = [];

  String? get havingClauses =>
      _havingClauses.isNotEmpty ? _havingClauses.join(' ') : null;

  HavingClauseCloner havingCloner() {
    return HavingClauseCloner(List.from(_havingClauses));
  }

  void importHavingClauses(HavingClauseCloner cloner) {
    _havingClauses = cloner.clauses;
  }

  /// Begin a HAVING condition.
  WhereOperation having(Field field) {
    if (_havingClauses.isNotEmpty) {
      throw StanzaException(
          'A query can only have one HAVING clause. Consider andHaving or orHaving.');
    }
    final package =
        WherePackage('HAVING', field, false, false, _havingClauses, this);
    return WhereOperation(package);
  }

  /// Continue a HAVING condition with AND.
  WhereOperation andHaving(Field field) {
    if (_havingClauses.isEmpty) {
      throw StanzaException(
          'A query HAVING clause must start with having(), not andHaving().');
    }
    final package =
        WherePackage('AND', field, false, false, _havingClauses, this);
    return WhereOperation(package);
  }

  /// Continue a HAVING condition with OR.
  WhereOperation orHaving(Field field) {
    if (_havingClauses.isEmpty) {
      throw StanzaException(
          'A query HAVING clause must start with having(), not orHaving().');
    }
    final package =
        WherePackage('OR', field, false, false, _havingClauses, this);
    return WhereOperation(package);
  }
}
