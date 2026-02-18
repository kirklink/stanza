import 'package:stanza/src/query.dart';
import 'package:stanza/src/shared/where_package.dart';
import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/value_substitution.dart';

/// The set of operations that can be performed on a [Field] in a conditional where clause.
class WhereOperation {
  final WherePackage _where;
  String? _comparison;
  String? _comparable;
  String? _fieldPreModifier;
  String? _fieldPostModifier;
  String? _raw;
  bool? _caseSensitive;

  WhereOperation(this._where);

  String get _subKeyBase =>
      _where.field.qualifiedName.replaceAll('.', '_');

  Query _attach({ValueSub? substitution}) {
    final fieldName = _where.field.expressionName;
    final comparison = _comparison ?? '';
    final comparable = _comparable ?? '';
    final preMod = _fieldPreModifier ?? '';
    final postMod = _fieldPostModifier ?? '';
    final open = _where.openBracket ? '(' : '';
    final close = _where.closeBracket ? ')' : '';
    var caseOpen = '';
    var caseClose = '';
    if (_caseSensitive != null && !_caseSensitive!) {
      caseOpen = 'LOWER(';
      caseClose = ')';
    }
    if (_raw != null) {
      final r = '${_where.operation} $_raw';
      _where.attachment.add(r);
    } else {
      final r =
          '${_where.operation} $open$caseOpen$preMod$fieldName$postMod$caseClose $comparison $comparable$close';
      _where.attachment.add(r);
    }
    if (substitution != null) _where.source.addSubstitution(substitution);
    return _where.source;
  }

  /// Escape special characters in LIKE patterns so user input is treated literally.
  static String _escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
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
    final sub = ValueSub(_subKeyBase, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is greater than another number.
  Query isGreaterThan(num number) {
    _comparison = '>';
    final sub = ValueSub(_subKeyBase, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is greater than or equal to another number.
  Query isGreaterThanOrEqualTo(num number) {
    _comparison = '>=';
    final sub = ValueSub(_subKeyBase, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is less than another number.
  Query isLessThan(num number) {
    _comparison = '<';
    final sub = ValueSub(_subKeyBase, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field is less than or equal to another number.
  Query isLessThanOrEqualTo(num number) {
    _comparison = '<=';
    final sub = ValueSub(_subKeyBase, number);
    _comparable = sub.token;
    return _attach(substitution: sub);
  }

  /// If the field matches another string (equality check).
  ///
  /// [caseSensitive] defaults to false (case-insensitive comparison using LOWER()).
  Query matches(String string, {bool caseSensitive = false}) {
    _comparison = '=';
    final value = caseSensitive ? string : string.toLowerCase();
    final sub = ValueSub(_subKeyBase, value);
    _comparable = sub.token;
    _caseSensitive = caseSensitive;
    return _attach(substitution: sub);
  }

  /// If the field starts with another string (uses LIKE).
  ///
  /// [caseSensitive] defaults to false (case-insensitive comparison using LOWER()).
  Query startsWith(String string, {bool caseSensitive = false}) {
    _comparison = 'LIKE';
    final escaped = _escapeLikePattern(caseSensitive ? string : string.toLowerCase());
    final sub = ValueSub('${_subKeyBase}_like', '$escaped%');
    _comparable = sub.token;
    _caseSensitive = caseSensitive;
    return _attach(substitution: sub);
  }

  /// If the field ends with another string (uses LIKE).
  ///
  /// [caseSensitive] defaults to false (case-insensitive comparison using LOWER()).
  Query endsWith(String string, {bool caseSensitive = false}) {
    _comparison = 'LIKE';
    final escaped = _escapeLikePattern(caseSensitive ? string : string.toLowerCase());
    final sub = ValueSub('${_subKeyBase}_like', '%$escaped');
    _comparable = sub.token;
    _caseSensitive = caseSensitive;
    return _attach(substitution: sub);
  }

  /// If the field contains another string (uses LIKE).
  ///
  /// [caseSensitive] defaults to false (case-insensitive comparison using LOWER()).
  Query contains(String string, {bool caseSensitive = false}) {
    _comparison = 'LIKE';
    final escaped = _escapeLikePattern(caseSensitive ? string : string.toLowerCase());
    final sub = ValueSub('${_subKeyBase}_like', '%$escaped%');
    _comparable = sub.token;
    _caseSensitive = caseSensitive;
    return _attach(substitution: sub);
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
  Query dateIsBefore(DateTime date) {
    _comparison = '<';
    final sub = ValueSub('${_subKeyBase}_date', date);
    _comparable = sub.token;
    _fieldPostModifier = '::date';
    return _attach(substitution: sub);
  }

  /// If the field is after another date.
  Query dateIsAfter(DateTime date) {
    _comparison = '>';
    final sub = ValueSub('${_subKeyBase}_date', date);
    _comparable = sub.token;
    _fieldPostModifier = '::date';
    return _attach(substitution: sub);
  }

  /// If the field is on another date.
  Query dateIsOn(DateTime date) {
    _comparison = '=';
    final sub = ValueSub('${_subKeyBase}_date', date);
    _comparable = sub.token;
    _fieldPostModifier = '::date';
    return _attach(substitution: sub);
  }

  /// If the field's value is in the given list.
  ///
  /// Produces `field IN (@val_0, @val_1, ...)` with parameterized values.
  /// Throws [StanzaException] if [values] is empty.
  Query isIn(List<Object> values) {
    if (values.isEmpty) {
      throw StanzaException('isIn() requires at least one value.');
    }
    final tokens = <String>[];
    for (var i = 0; i < values.length; i++) {
      final sub = ValueSub('${_subKeyBase}_in_$i', values[i]);
      _where.source.addSubstitution(sub);
      tokens.add(sub.token);
    }
    _raw =
        '${_where.openBracket ? '(' : ''}${_where.field.expressionName} IN (${tokens.join(', ')})${_where.closeBracket ? ')' : ''}';
    _where.attachment.add('${_where.operation} $_raw');
    return _where.source;
  }

  /// If the field's value is not in the given list.
  ///
  /// Produces `field NOT IN (@val_0, @val_1, ...)` with parameterized values.
  /// Throws [StanzaException] if [values] is empty.
  Query isNotIn(List<Object> values) {
    if (values.isEmpty) {
      throw StanzaException('isNotIn() requires at least one value.');
    }
    final tokens = <String>[];
    for (var i = 0; i < values.length; i++) {
      final sub = ValueSub('${_subKeyBase}_notin_$i', values[i]);
      _where.source.addSubstitution(sub);
      tokens.add(sub.token);
    }
    _raw =
        '${_where.openBracket ? '(' : ''}${_where.field.expressionName} NOT IN (${tokens.join(', ')})${_where.closeBracket ? ')' : ''}';
    _where.attachment.add('${_where.operation} $_raw');
    return _where.source;
  }

  /// If the field's value is between [low] and [high] (inclusive).
  ///
  /// Produces `field BETWEEN @low AND @high` with parameterized values.
  Query isBetween(Object low, Object high) {
    final subLow = ValueSub('${_subKeyBase}_between_low', low);
    final subHigh = ValueSub('${_subKeyBase}_between_high', high);
    _where.source.addSubstitution(subLow);
    _where.source.addSubstitution(subHigh);
    _raw =
        '${_where.openBracket ? '(' : ''}${_where.field.expressionName} BETWEEN ${subLow.token} AND ${subHigh.token}${_where.closeBracket ? ')' : ''}';
    _where.attachment.add('${_where.operation} $_raw');
    return _where.source;
  }

  /// A query condition supplied as a raw string.
  ///
  /// Use with caution — this bypasses parameterization.
  Query raw(String condition) {
    _raw = condition;
    return _attach();
  }
}
