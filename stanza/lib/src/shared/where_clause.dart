import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/shared/where_operations.dart';
import 'package:stanza/src/shared/where_package.dart';

class WhereClauseCloner {
  final List<String> clauses;
  final int bracketDepth;
  WhereClauseCloner(this.clauses, this.bracketDepth);
}

mixin WhereClause on Query {

  List<String> _clauses = [];
  int bracketDepth = 0;

  String get whereClauses => _clauses.length > 0 ? _clauses.join(' ') : null;

  WhereClauseCloner cloner() {
    return WhereClauseCloner(List.from(_clauses), bracketDepth);
  }

  void importWhereClauses(WhereClauseCloner cloner) {
    _clauses = cloner.clauses;
    bracketDepth = cloner.bracketDepth;
  }

  /// Begin a conditional statement in a query.
  /// 
  /// [openBracket] and [closeBracket] can be made true to apply simple grouping to
  /// conditional statements.
  WhereOperation where(Field field, {bool openBracket: false, bool closeBracket: false}) {
    if (_clauses.length != 0) throw StanzaException('A query can only have one WHERE clause. Consider AND or OR.');
    if (openBracket) bracketDepth++;
    if (closeBracket) bracketDepth--;
    var package = WherePackage('WHERE', field, openBracket, closeBracket, _clauses, this);
    var op = WhereOperation(package);
    return op;
  }

  /// Continue a conditional statement with an AND condition.
  /// 
  /// [openBracket] and [closeBracket] can be made true to apply simple grouping to
  /// conditional statements.
  WhereOperation and(Field field, {bool openBracket: false, bool closeBracket: false}) {
    if (_clauses.length == 0) throw StanzaException('A query WHERE clause must start with WHERE, not AND.');
    if (openBracket) bracketDepth++;
    if (closeBracket) bracketDepth--;
    var package = WherePackage('AND', field, openBracket, closeBracket, _clauses, this);
    var op = WhereOperation(package);
    return op;
  }

  /// Continue a conditional statement with an OR condition.
  /// 
  /// [openBracket] and [closeBracket] can be made true to apply simple grouping to
  /// conditional statements.
  WhereOperation or(Field field, {bool openBracket: false, bool closeBracket: false}) {
    if (_clauses.length == 0) throw StanzaException('A query WHERE clause must start with WHERE, not OR.');
    if (openBracket) bracketDepth++;
    if (closeBracket) bracketDepth--;
    var package = WherePackage('OR', field, openBracket, closeBracket, _clauses, this);
    var op = WhereOperation(package);
    return op;
  }

}