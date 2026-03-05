import 'package:stanza/stanza.dart';

part 'models.g.dart';

@StanzaEntity()
class User {
  @StanzaKey(autoIncrement: true)
  final int id;

  @StanzaField(length: 100, unique: true)
  final String email;

  @StanzaField(length: 50)
  final String name;

  @StanzaField(defaultValue: 'now()')
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });
}

@StanzaEntity()
class Post {
  @StanzaKey(autoIncrement: true)
  final int id;

  final String title;

  final String body;

  @StanzaRef(User, onDelete: 'CASCADE')
  final int authorId;

  @StanzaField(defaultValue: 'now()')
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.createdAt,
  });
}
