/// Marks a class as a database entity.
///
/// The class must have a const constructor with named parameters
/// matching all non-ignored fields.
///
/// ```dart
/// @Entity()
/// class User {
///   @PrimaryKey(autoIncrement: true)
///   final int id;
///   @Field(unique: true)
///   final String email;
///   const User({required this.id, required this.email});
/// }
/// ```
class Entity {
  /// Override the table name. Defaults to snake_case of the class name.
  final String? name;

  const Entity({this.name});
}

/// Configures a field's database column mapping.
///
/// Fields without `@Field` are auto-mapped using Dart type inference.
/// Use this annotation to customize column behavior.
///
/// ```dart
/// @Field(length: 100, unique: true)
/// final String email;
///
/// @Field(defaultValue: 'now()')
/// final DateTime createdAt;
///
/// @Field(ignore: true)
/// final String cachedValue;
/// ```
class Field {
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

  const Field({
    this.name,
    this.length,
    this.unique = false,
    this.defaultValue,
    this.type,
    this.ignore = false,
  });
}

/// Marks a field as the primary key.
///
/// Only one field per entity may be annotated with `@PrimaryKey`.
class PrimaryKey {
  /// Whether the primary key auto-increments (SERIAL/BIGSERIAL).
  final bool autoIncrement;

  const PrimaryKey({this.autoIncrement = true});
}

/// Marks a field as a foreign key reference to another entity.
///
/// ```dart
/// @References(User, onDelete: 'CASCADE')
/// final int authorId;
/// ```
class References {
  /// The referenced entity class.
  final Type entity;

  /// The column on the referenced table. Defaults to `'id'`.
  final String? column;

  /// Referential action on delete: `'CASCADE'`, `'SET NULL'`, `'RESTRICT'`.
  final String? onDelete;

  const References(this.entity, {this.column, this.onDelete});
}

/// Marks a class as the database entry point.
///
/// Lists all entity types that belong to this database.
/// The code generator produces typed `TableAccessor` fields for each entity.
///
/// ```dart
/// @Database(entities: [User, Post])
/// class AppDatabase extends $AppDatabase {
///   AppDatabase(Stanza connection) : super(connection);
/// }
/// ```
class Database {
  /// All entity types managed by this database.
  final List<Type> entities;

  const Database({required this.entities});
}
