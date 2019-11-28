/// The annotation to convert a Dart class into a Stanza database table interface.
///
/// [name]: rename the Stanza table to correspond with a database table name.
/// [snakeCase]: automatically convert the table name and field names to snake_case, unless
/// provided explicitly with a 'name' parameter.
class StanzaEntity {
  final String name;
  final bool snakeCase;
  const StanzaEntity({this.name, this.snakeCase = false});
}

/// The annotation to enhance a Dart class property into a Stanza database field interface.
///
/// [StanzaField] is not required and only necessary if additional annotations are required
/// on the field. Otherwise, Dart class properties of a [StanzaEntity] are automatically converted
/// to fields.
///
/// [name]: sets an explict name on a field to correspond with a database field name.
/// [readOnly]: will read this field from the database but not write it to the database. Useful
/// for things like id's or timestamps.
class StanzaField {
  final String name;
  final bool readOnly;
  const StanzaField({this.name, this.readOnly = false});
}
