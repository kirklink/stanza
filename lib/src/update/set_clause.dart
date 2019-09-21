import 'dart:mirrors';

import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/update_query.dart';


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
    return SetValue(field, this, q);
  }

  SetClause clone() {
    var x = SetClause();
    x._clauses = Map.from(_clauses);
    return x;
  }

}

class SetValue<T> {

  final Field field;
  final SetClause parent;
  final UpdateQuery src;
  

  SetValue(this.field, this.parent, this.src);


  UpdateQuery _attach(dynamic value) {
    var sub = ValueSub(field.dbName, value);
    src.addSubstitution(sub);
    parent._clauses[field.dbName] = sub.token;
    return src;
  }

  UpdateQuery number(num number) {
    return _attach(number);
  }

  UpdateQuery integer(int integer) {
    return _attach(integer);
  }

  UpdateQuery float(double float) {
    return _attach(float);
  }

  UpdateQuery string(String string) {
    return _attach(string);
  }

  UpdateQuery datetime(DateTime datetime) {
    return _attach(datetime);
  }

  UpdateQuery boolean(bool boolean) {
    return _attach(boolean);
  }

  UpdateQuery entity(T entity) {
    var meer = reflect(entity).getField(Symbol(field.appName)).reflectee;
    return _attach(meer);
  }

  UpdateQuery any(dynamic d) {
    return _attach(d);
  }

}