import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/update/update_query.dart';

class SetClause implements QueryClause {
  Map<String, String> _clauses = {};

  @override
  String get clause {
    return _clauses.entries.map((e) => '${e.key} = ${e.value}').join(', ');
  }

  SetValue column(Field field, Query q) {
    return SetValue(field, this, q as UpdateQuery);
  }

  @override
  SetClause clone() {
    final x = SetClause();
    x._clauses = Map.from(_clauses);
    return x;
  }
}

/// The segment of an update query that sets a value on a column.
///
/// Type-safe options are provided as a convenience but a dynamic value can also be used.
class SetValue {
  final Field field;
  final SetClause parent;
  final UpdateQuery src;

  SetValue(this.field, this.parent, this.src);

  UpdateQuery _attach(dynamic value) {
    final sub = ValueSub(field.name, value);
    src.addSubstitution(sub);
    parent._clauses[field.name] = sub.token;
    return src;
  }

  /// Set the value to a number.
  UpdateQuery number(num number) => _attach(number);

  /// Set the value to an integer.
  UpdateQuery integer(int integer) => _attach(integer);

  /// Set the value to a double (float).
  UpdateQuery float(double float) => _attach(float);

  /// Set the value to a string.
  UpdateQuery string(String string) => _attach(string);

  /// Set the value to a datetime.
  UpdateQuery datetime(DateTime datetime) => _attach(datetime);

  /// Set the value to a boolean.
  UpdateQuery boolean(bool boolean) => _attach(boolean);

  /// Set the value to a dynamic value.
  UpdateQuery any(dynamic value) => _attach(value);
}
