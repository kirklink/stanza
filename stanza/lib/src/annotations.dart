/// Marks a class as a database entity.
///
/// The class must have a const constructor with named parameters
/// matching all non-ignored fields.
///
/// ```dart
/// @StanzaEntity()
/// class User {
///   @StanzaKey(autoIncrement: true)
///   final int id;
///   @StanzaField(unique: true)
///   final String email;
///   const User({required this.id, required this.email});
/// }
/// ```
class StanzaEntity {
  /// Override the table name. Defaults to snake_case of the class name.
  final String? name;

  /// When `true`, the code generator emits a `CellarCollection` constant
  /// alongside the table descriptor. The collection name matches [name]
  /// (or the auto-derived table name). Requires `package:cellar` to be
  /// imported in the source file.
  final bool cellar;

  /// Creates an entity annotation, optionally overriding the table [name].
  const StanzaEntity({this.name, this.cellar = false});
}

/// Configures a field's database column mapping.
///
/// Fields without `@StanzaField` are auto-mapped using Dart type inference.
/// Use this annotation to customize column behavior.
///
/// ```dart
/// @StanzaField(length: 100, unique: true)
/// final String email;
///
/// @StanzaField(defaultValue: 'now()')
/// final DateTime createdAt;
///
/// @StanzaField(ignore: true)
/// final String cachedValue;
/// ```
class StanzaField {
  /// Override the column name. Defaults to snake_case of the field name.
  final String? name;

  /// Maximum length for VARCHAR columns.
  final int? length;

  /// Whether this column has a UNIQUE constraint.
  final bool unique;

  /// SQL DEFAULT expression (e.g. `'now()'`, `"'active'"`, `'0'`).
  final String? defaultValue;

  /// Override the PostgreSQL type (e.g. `'jsonb'`, `'uuid'`, `'text[]'`).
  final String? type;

  /// Skip this field entirely — no database column generated.
  final bool ignore;

  /// Whether this field should be included in full-text search indexes.
  /// Only meaningful for String (text) fields. Used by Cellar backend
  /// code generation to set `fts: true` on the corresponding field.
  final bool fts;

  /// Creates a field annotation with optional column configuration.
  const StanzaField({
    this.name,
    this.length,
    this.unique = false,
    this.defaultValue,
    this.type,
    this.ignore = false,
    this.fts = false,
  });
}

/// Marks a field as the primary key.
///
/// Only one field per entity may be annotated with `@StanzaKey`.
class StanzaKey {
  /// Whether the primary key auto-increments (SERIAL/BIGSERIAL).
  final bool autoIncrement;

  /// Creates a primary key annotation, with [autoIncrement] defaulting to true.
  const StanzaKey({this.autoIncrement = true});
}

/// Marks a field as a foreign key reference to another entity.
///
/// ```dart
/// @StanzaRef(User, onDelete: 'CASCADE')
/// final int authorId;
/// ```
class StanzaRef {
  /// The referenced entity class.
  final Type entity;

  /// The column on the referenced table. Defaults to `'id'`.
  final String? column;

  /// Referential action on delete: `'CASCADE'`, `'SET NULL'`, `'RESTRICT'`.
  final String? onDelete;

  /// Creates a foreign key reference to [entity], optionally specifying the
  /// target [column] and [onDelete] action.
  const StanzaRef(this.entity, {this.column, this.onDelete});
}

/// Marks a class as the database entry point.
///
/// Lists all entity types that belong to this database.
/// The code generator produces typed `TableAccessor` fields for each entity.
///
/// ```dart
/// @StanzaDatabase(entities: [User, Post])
/// class AppDatabase extends $AppDatabase {
///   AppDatabase(Stanza connection) : super(connection);
/// }
/// ```
class StanzaDatabase {
  /// All entity types managed by this database.
  final List<Type> entities;

  /// Creates a database annotation listing the managed [entities].
  const StanzaDatabase({required this.entities});
}
