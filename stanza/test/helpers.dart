import 'package:stanza/stanza.dart';

// -- Entities (immutable, const constructors) --

class User {
  final int id;
  final String email;
  final String name;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });
}

class Post {
  final int id;
  final String title;
  final String body;
  final int authorId;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.createdAt,
  });
}

// -- Insert companions --

class UserInsert {
  final String email;
  final String name;
  final DateTime? createdAt;

  const UserInsert({required this.email, required this.name, this.createdAt});

  Map<String, dynamic> toRow() => {
        'email': email,
        'name': name,
        if (createdAt != null) 'created_at': createdAt,
      };
}

class PostInsert {
  final String title;
  final String body;
  final int authorId;
  final DateTime? createdAt;

  const PostInsert({
    required this.title,
    required this.body,
    required this.authorId,
    this.createdAt,
  });

  Map<String, dynamic> toRow() => {
        'title': title,
        'body': body,
        'author_id': authorId,
        if (createdAt != null) 'created_at': createdAt,
      };
}

// -- Update companions --

class UserUpdate {
  final String? email;
  final String? name;
  final DateTime? createdAt;

  const UserUpdate({this.email, this.name, this.createdAt});

  Map<String, dynamic> toRow() => {
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (createdAt != null) 'created_at': createdAt,
      };
}

// -- Table descriptors (what stanza_builder will generate) --

class $UserTable extends TableDescriptor<User> {
  @override
  String get tableName => 'users';

  final id = const IntColumn('id', 'users');
  final email = const StringColumn('email', 'users');
  final name = const StringColumn('name', 'users');
  final createdAt = const DateTimeColumn('created_at', 'users');

  @override
  List<Column> get columns => [id, email, name, createdAt];

  @override
  Column get primaryKey => id;

  @override
  User fromRow(Map<String, dynamic> row) => User(
        id: row['id'] as int,
        email: row['email'] as String,
        name: row['name'] as String,
        createdAt: row['created_at'] as DateTime,
      );
}

class $PostTable extends TableDescriptor<Post> {
  @override
  String get tableName => 'posts';

  final id = const IntColumn('id', 'posts');
  final title = const StringColumn('title', 'posts');
  final body = const StringColumn('body', 'posts');
  final authorId = const IntColumn('author_id', 'posts');
  final createdAt = const DateTimeColumn('created_at', 'posts');

  @override
  List<Column> get columns => [id, title, body, authorId, createdAt];

  @override
  Column get primaryKey => id;

  @override
  Post fromRow(Map<String, dynamic> row) => Post(
        id: row['id'] as int,
        title: row['title'] as String,
        body: row['body'] as String,
        authorId: row['author_id'] as int,
        createdAt: row['created_at'] as DateTime,
      );
}
