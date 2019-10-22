class Field {
  
  final String _tableName;
  final String _fieldName;
  String _operation;
  String _newName;

  Field(this._tableName, this._fieldName);
  
  String get sql {
    var buf = StringBuffer();
    if (_operation != null) buf.write("${_operation}(");
    buf.write("$_tableName.$_fieldName");
    if (_operation != null) buf.write(")");
    if (_newName != null) buf.write(" AS $_newName");
    return buf.toString();
  }

  String get name => _fieldName;

  String get qualifiedName => "$_tableName.$_fieldName";
  
  Field rename(String newName) {
    _newName = newName;
    return this;
  } 
  
  Field sum() {
    _operation = 'SUM';
    return this;
  }

  Field avg() {
    _operation = 'AVG';
    return this;
  }

  Field count() {
    _operation = 'COUNT';
    return this;
  }

  Field max() {
    _operation = 'MAX';
    return this;
  }

  Field min() {
    _operation = 'MIN';
    return this;
  }
  
  
  Field aggregate(String operation) {
    _operation = operation;
    return this;
  } 

}