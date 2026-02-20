import 'package:stanza/stanza.dart';

part 'models.g.dart';

@Entity()
class User {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Field(length: 100, unique: true)
  final String email;

  @Field(length: 50)
  final String name;

  @Field(defaultValue: 'now()')
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });
}

@Entity()
class Post {
  @PrimaryKey(autoIncrement: true)
  final int id;

  final String title;

  final String body;

  @References(User, onDelete: 'CASCADE')
  final int authorId;

  @Field(defaultValue: 'now()')
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.createdAt,
  });
}
