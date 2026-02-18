/// The annotation to convert a Dart class into a Stanza database table interface.
///
/// [name]: rename the Stanza table to correspond with a database table name.
/// [snakeCase]: automatically convert the table name and field names to snake_case, unless
/// provided explicitly with a 'name' parameter.
/// [readOnly]: Throws a StanzaEntityException if tried to write to the database.
class StanzaEntity {
  final String? name;
  final bool snakeCase;
  final bool readOnly;
  const StanzaEntity({this.name, this.snakeCase = false, this.readOnly = false});
}

/// The annotation to enhance a Dart class property into a Stanza database field interface.
///
/// [StanzaField] is not required and only necessary if additional annotations are required
/// on the field. Otherwise, Dart class properties of a [StanzaEntity] are automatically converted
/// to fields.
///
/// [name]: sets an explicit name on a field to correspond with a database field name.
/// [readOnly]: will read this field from the database but not write it to the database. Useful
/// for things like id's or timestamps.
/// [ignore]: will ignore this field completely; it will not be in the table fields.
class StanzaField {
  final String? name;
  final bool readOnly;
  final bool ignore;
  const StanzaField({this.name, this.readOnly = false, this.ignore = false});
}

/// Declares a belongs-to relationship on a foreign key field.
///
/// Place on the foreign key field (e.g., `ownerId`) to indicate it references
/// another [StanzaEntity]. The code generator will produce typed join helpers
/// and result extraction methods.
///
/// ```dart
/// @StanzaEntity(name: 'mammal', snakeCase: true)
/// class Animal {
///   @BelongsTo(Owner)
///   late int ownerId;
/// }
/// ```
///
/// [parent]: The type of the related entity (must be annotated with [StanzaEntity]).
/// [targetKey]: The column name on the parent table to join against. Defaults to 'id'.
class BelongsTo {
  final Type parent;
  final String targetKey;
  const BelongsTo(this.parent, {this.targetKey = 'id'});
}
