import 'package:stanza/src/name_converter.dart';


class Field {
  
  final NameConverter _name;
  final String _table;
  String _operation;
  String _asName;

  String get appName => _name.app;
  String get jsonName => _name.json;
  String get dbNameQualified {
    var name = _table + '.' + _name.db;
    if (_operation != null) name = '$_operation($name)';
    if (_asName != null) name = '$name AS $_asName';
    return name;
  }
  String get dbName {
    var name = _name.db;
    if (_operation != null) name = '$_operation($name)';
    if (_asName != null) name = '$name AS $_asName';
    return name;
  }

  Field(this._name, this._table);
  
  void sum() {
    _operation = 'SUM';
  }

  void avg() {
    _operation = 'AVG';
  }

  void max() {
    _operation = 'MAX';
  }

  void min() {
    _operation = 'MIN';
  }

  void aggregate(String operation) {
    _operation = operation;
  }

  void asName(String asName) {
    _asName = asName;
  }

}