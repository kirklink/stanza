import 'package:cellar/cellar.dart';
import 'package:stanza/stanza.dart';

part 'cellar_models.g.dart';

/// A Cellar-targeted entity with String ULID primary key.
///
/// Demonstrates dual-backend support: the same entity generates both
/// a Stanza `$Table` (for typed queries) and a `CellarCollection`
/// constant (for Cellar collection registration).
@StanzaEntity(cellar: true)
class Episode {
  @StanzaKey(autoIncrement: false)
  final String id;

  @StanzaField(fts: true)
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
@StanzaEntity(name: 'app_settings', cellar: true)
class Setting {
  @StanzaKey(autoIncrement: false)
  final String id;

  @StanzaField(unique: true)
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
