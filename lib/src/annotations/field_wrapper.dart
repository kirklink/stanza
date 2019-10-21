class FieldWrapper {
  
  final String _tableName;
  final String _fieldName;
  String _operation;
  String _newName;

  FieldWrapper(this._tableName, this._fieldName);
  
  String get name {
    var buf = StringBuffer();
    if (_operation != null) buf.write("${_operation}(");
    buf.write("$_tableName.$_fieldName");
    if (_operation != null) buf.write(")");
    if (_newName != null) buf.write(" AS $_newName");
    return buf.toString();
  }
  
  FieldWrapper rename(String newName) {
    _newName = newName;
    return this;
  } 
  
  FieldWrapper sum() {
    _operation = 'SUM';
    return this;
  }

  FieldWrapper avg() {
    _operation = 'AVG';
    return this;
  }

  FieldWrapper max() {
    _operation = 'MAX';
    return this;
  }

  FieldWrapper min() {
    _operation = 'MIN';
    return this;
  }
  
  
  FieldWrapper aggregate(String operation) {
    _operation = operation;
    return this;
  } 

}