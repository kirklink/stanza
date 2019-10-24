import 'package:stanza/src/query.dart';
import 'package:stanza/src/shared/where_package.dart';
import 'package:stanza/src/value_substitution.dart';


class WhereOperation {
  final WherePackage _where;
  String _comparison;
  String _comparable;
  bool _caseSensitive;
  
  WhereOperation(this._where);

  Query _attach({ValueSub substitution}) {
    var fieldName = _where.field.qualifiedName;
    var open = _where.openBracket ? '(' : '';
    var close = _where.closeBracket ? ')' : '';
    var caseOpen = '';
    var caseClose = '';
    if (_caseSensitive != null && !_caseSensitive) {
      caseOpen = 'LOWER(';
      caseClose = ')';
    }
    var r = '${_where.operation} $open$caseOpen${fieldName}$caseClose $_comparison $_comparable$close';
    _where.attachment.add(r);
    if (substitution != null) _where.source.addSubstitution(substitution);
    return _where.source;
  }

  String _formatCaseSensitive(String input, bool caseSensitive) {
    if (caseSensitive) {
      _caseSensitive = true;
      return input;
    } else {
      _caseSensitive = false;
      return input?.toLowerCase();
    }
  }

  String _formatAsString(String input) {
    return "'$input'";
  }

  Query isNotNull() {
    _comparison = 'IS NOT';
    _comparable = 'NULL';
    return _attach();
  }

  Query isNull() {
    _comparison = 'IS';
    _comparable = 'NULL';
    return _attach();
  }

  Query equalTo(num number) {
    _comparison = '=';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  Query greaterThan(num number) {
    _comparison = '>';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  Query greaterThanOrEqualTo(num number) {
    _comparison = '>=';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  Query lessThan(num number) {
    _comparison = '<';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  Query lessThanOrEqualTo(num number) {
    _comparison = '<=';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  Query matches(String string, {bool caseSensitive: false}) {
    _comparison = '=';
    _comparable = _formatAsString(_formatCaseSensitive(string, caseSensitive));
    _caseSensitive = caseSensitive;
    return _attach();
  }

  Query startsWith(String string, {bool caseSensitive: false}) {
    _comparison = 'LIKE';
    _comparable = _formatAsString('${_formatCaseSensitive(string, caseSensitive)}%');
    _caseSensitive = caseSensitive;
    return _attach();
  }

  Query endsWith(String string, {bool caseSensitive: false}) {
    _comparison = 'LIKE';
    _comparable = _formatAsString('%${_formatCaseSensitive(string, caseSensitive)}');
    _caseSensitive = caseSensitive;
    return _attach();
  }

  Query contains(String string, {bool caseSensitive: false}) {
    _comparison = 'LIKE';
    _comparable = _formatAsString('%${_formatCaseSensitive(string, caseSensitive)}%');
    _caseSensitive = caseSensitive;
    return _attach();
  }

  Query isTrue() {
    _comparison = '=';
    _comparable = 'true';
    return _attach();
  }

  Query isFalse() {
    _comparison = '=';
    _comparable = 'false';
    return _attach();
  }

  Query isBefore(DateTime date) {
    _comparable = '<';
    _comparable = '${date.toString()}::date';
    return _attach();
  }

  Query isAfter(DateTime date) {
    _comparable = '>';
    _comparable = '${date.toString()}::date';
    return _attach();
  }


}