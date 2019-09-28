import 'package:stanza/src/exception.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/value_substitution.dart';


abstract class Query {

  Table _table;

  var _substitutionValues = Map<String, dynamic>();

  Query(this._table);

  String get tableName => _table.dbName;
  Table get table => _table;
  Map<String, dynamic> get substitutionValues => _substitutionValues;

  String statement({bool pretty: false}) {
    throw QueryException('Statement is not implemented.');
  }

  String toString() {
    if (_substitutionValues.isEmpty) return 'Type: ${this.runtimeType}\n${statement(pretty: true)}';
    return 'Type: ${this.runtimeType}\n${this.runtimeType}\n${statement(pretty: true)}\nsubstitutionValues: ${_substitutionValues.toString()}';
  }

  
  void addSubstitution(ValueSub sub) {
    _substitutionValues[sub.key] = sub.value;
  }

  void importSubstitutionValues(Map<String, dynamic> subs) {
    _substitutionValues = Map.from(subs);
  }


  Query fork() {
    throw QueryException('Clone is not implemented.');
  }


}