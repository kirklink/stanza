/// A [Field] takes the place of the class properties in the generated code of a StanzaEntity.
///
/// A [Field] is the generated code representation of Dart class properties that provide
/// an interface with database fields. A [Field] produces the corresponding field name of database fields
/// and also contain functions to manipulate fields in Postgresql queries.
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

  /// The String representation of the corresponding database field name.
  String get name => _fieldName;

  /// The String representation of the corresponding table and field name 'tableName.fieldName'
  String get qualifiedName => "$_tableName.$_fieldName";

  /// Rename a field to a corresponding database field name. Postgresql AS.
  ///
  /// Can also be used to rename calculated aggregate field names.
  Field rename(String newName) {
    _newName = newName;
    return this;
  }

  /// Perform a SUM operation on a field.
  Field sum() {
    _operation = 'SUM';
    return this;
  }

  /// Perform an AVG operation on a field.
  Field avg() {
    _operation = 'AVG';
    return this;
  }

  /// Perform a COUNT operation on a field.
  Field count() {
    _operation = 'COUNT';
    return this;
  }

  /// Perform a MAX operation on a field.
  Field max() {
    _operation = 'MAX';
    return this;
  }

  /// Perform a MIN operation on a field.
  Field min() {
    _operation = 'MIN';
    return this;
  }

  /// Perform a supplied operation on a field.
  Field aggregate(String operation) {
    _operation = operation;
    return this;
  }
}
