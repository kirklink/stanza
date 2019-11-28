import 'package:stanza/src/query.dart';
import 'package:stanza/src/shared/where_package.dart';
import 'package:stanza/src/value_substitution.dart';

/// The set of operations that can be performed on a [Field] in a conditional where clause.
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

  /// If the field is not null.
  Query isNotNull() {
    _comparison = 'IS NOT';
    _comparable = 'NULL';
    return _attach();
  }

  /// If the field is null.
  Query isNull() {
    _comparison = 'IS';
    _comparable = 'NULL';
    return _attach();
  }

  /// If the field is equal to another number.
  Query isEqualTo(num number) {
    _comparison = '=';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is greater than another number.
  Query isGreaterThan(num number) {
    _comparison = '>';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is greater than or equal to another number.
  Query isGreaterThanOrEqualTo(num number) {
    _comparison = '>=';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is less than another number.
  Query isLessThan(num number) {
    _comparison = '<';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is less than or equal to another number.
  Query isLessThanOrEqualTo(num number) {
    _comparison = '<=';
    var sub = ValueSub(_where.field.qualifiedName, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field matches another string.
  Query matches(String string, {bool caseSensitive: false}) {
    _comparison = '=';
    _comparable = _formatAsString(_formatCaseSensitive(string, caseSensitive));
    _caseSensitive = caseSensitive;
    return _attach();
  }

  /// If the field starts with another string.
  Query startsWith(String string, {bool caseSensitive: false}) {
    _comparison = 'LIKE';
    _comparable = _formatAsString('${_formatCaseSensitive(string, caseSensitive)}%');
    _caseSensitive = caseSensitive;
    return _attach();
  }

  /// If the field ends with another string.
  Query endsWith(String string, {bool caseSensitive: false}) {
    _comparison = 'LIKE';
    _comparable = _formatAsString('%${_formatCaseSensitive(string, caseSensitive)}');
    _caseSensitive = caseSensitive;
    return _attach();
  }

  /// If the field contains another string.
  Query contains(String string, {bool caseSensitive: false}) {
    _comparison = 'LIKE';
    _comparable = _formatAsString('%${_formatCaseSensitive(string, caseSensitive)}%');
    _caseSensitive = caseSensitive;
    return _attach();
  }

  /// If the field is True.
  Query isTrue() {
    _comparison = '=';
    _comparable = 'true';
    return _attach();
  }

  /// If the field is False.
  Query isFalse() {
    _comparison = '=';
    _comparable = 'false';
    return _attach();
  }

  /// If the field is before another date.
  Query isBefore(DateTime date) {
    _comparison = '<';
    _comparable = '${date.toString()}::date';
    return _attach();
  }

  /// If the field is after another date.
  Query isAfter(DateTime date) {
    _comparison = '>';
    _comparable = '${date.toString()}::date';
    return _attach();
  }

  /// If the field is on another date.
  Query isOn(DateTime date) {
    _comparison = '=';
    _comparable = '${date.toString()}::date';
    return _attach();

  }


}