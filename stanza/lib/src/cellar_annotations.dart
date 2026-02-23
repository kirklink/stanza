/// Marks an `@Entity` class for Cellar collection schema generation.
///
/// When present alongside `@Entity`, the code generator emits a
/// `$cellarSchema` getter on the generated `$Table` class. This getter
/// returns a `Map<String, dynamic>` compatible with `Collection.fromJson()`.
///
/// Cellar auto-manages system fields (`id`, `created_at`, `updated_at`),
/// so these are excluded from the generated schema.
///
/// ```dart
/// @Entity()
/// @CellarCollection()
/// class Episode {
///   @PrimaryKey(autoIncrement: false)
///   final String id;
///   @Field(fts: true)
///   final String content;
///   final double importance;
///   final DateTime createdAt;
///   final DateTime updatedAt;
///   const Episode({...});
/// }
/// ```
///
/// Usage at registration time:
/// ```dart
/// import 'package:cellar/cellar.dart';
///
/// final cellar = Cellar.open('data.db', collections: [
///   Collection.fromJson($EpisodeTable().$cellarSchema),
/// ]);
/// ```
class CellarCollection {
  /// Override the collection name. Defaults to the `@Entity` table name.
  final String? name;

  /// Creates a Cellar collection annotation, optionally overriding the
  /// collection [name].
  const CellarCollection({this.name});
}
