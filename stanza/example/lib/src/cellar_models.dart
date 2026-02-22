import 'package:stanza/stanza.dart';

part 'cellar_models.g.dart';

/// A Cellar-targeted entity with String ULID primary key.
///
/// Demonstrates dual-backend support: the same entity generates both
/// a Stanza `$Table` (for typed queries) and a `$cellarSchema` map
/// (for Cellar collection registration via `Collection.fromJson()`).
@Entity()
@CellarCollection()
class Episode {
  @PrimaryKey(autoIncrement: false)
  final String id;

  @Field(fts: true)
  final String content;

  final String type;

  final double importance;

  final bool consolidated;

  final DateTime createdAt;

  final DateTime updatedAt;

  const Episode({
    required this.id,
    required this.content,
    required this.type,
    required this.importance,
    required this.consolidated,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// An entity with nullable fields, unique constraint, and custom collection name.
@Entity()
@CellarCollection(name: 'app_settings')
class Setting {
  @PrimaryKey(autoIncrement: false)
  final String id;

  @Field(unique: true)
  final String key;

  final String? value;

  final DateTime createdAt;

  final DateTime updatedAt;

  const Setting({
    required this.id,
    required this.key,
    this.value,
    required this.createdAt,
    required this.updatedAt,
  });
}
