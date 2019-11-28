import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/update/update_query.dart';

class SetClause implements QueryClause {
  var _clauses = Map<String, String>();

  String get clause {
    String r = '';
    _clauses.forEach((k, v) {
      r = '$r, $k = $v';
    });
    return r.replaceFirst(', ', '');
  }

  SetValue column<T>(Field field, Query q) {
    return SetValue(field, this, q as UpdateQuery);
  }

  SetClause clone() {
    var x = SetClause();
    x._clauses = Map.from(_clauses);
    return x;
  }
}

/// The segment of a update query that sets a value on a column.
///
/// Typesafe options are provided as a convenience but a dynamic value can also be used.
class SetValue<T> {
  final Field field;
  final SetClause parent;
  final UpdateQuery src;

  SetValue(this.field, this.parent, this.src);

  UpdateQuery _attach(dynamic value) {
    var sub = ValueSub(field.name, value);
    src.addSubstitution(sub);
    parent._clauses[field.name] = sub.token;
    return src;
  }

  /// Set the value to a number.
  UpdateQuery number(num number) {
    return _attach(number);
  }

  /// Set the value to an integer.
  UpdateQuery integer(int integer) {
    return _attach(integer);
  }

  /// Set the value to a double (float).
  UpdateQuery float(double float) {
    return _attach(float);
  }

  /// Set the value to a string.
  UpdateQuery string(String string) {
    return _attach(string);
  }

  /// Set the value to a datetime.
  UpdateQuery datetime(DateTime datetime) {
    return _attach(datetime);
  }

  /// Set the value to a boolean.
  UpdateQuery boolean(bool boolean) {
    return _attach(boolean);
  }

  // UpdateQuery entity(T entity) {
  //   var meer = reflect(entity).getField(Symbol(field.appName)).reflectee;
  //   return _attach(meer);
  // }

  /// Set the value to a dynamic value.
  UpdateQuery any(dynamic value) {
    return _attach(value);
  }
}
