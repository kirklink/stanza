// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// EntityGenerator
// **************************************************************************

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

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'users',
        columns: [
          SchemaColumn(
              name: 'id',
              type: ColumnType('serial'),
              isPrimaryKey: true,
              isSerial: true),
          SchemaColumn(
              name: 'email',
              type: ColumnType('varchar(100)'),
              nullable: false,
              isUnique: true),
          SchemaColumn(
              name: 'name', type: ColumnType('varchar(50)'), nullable: false),
          SchemaColumn(
              name: 'created_at',
              type: ColumnType('timestamptz'),
              nullable: false,
              defaultValue: 'now()'),
        ],
        constraints: [
          SchemaConstraint(
              name: 'users_pkey',
              kind: ConstraintKind.primaryKey,
              columns: ['id']),
          SchemaConstraint(
              name: 'users_email_key',
              kind: ConstraintKind.unique,
              columns: ['email']),
        ],
      );
}

class UserInsert {
  final String email;
  final String name;
  final DateTime? createdAt;

  const UserInsert({
    required this.email,
    required this.name,
    this.createdAt,
  });

  Map<String, dynamic> toRow() => {
        'email': email,
        'name': name,
        if (createdAt != null) 'created_at': createdAt,
      };
}

class UserUpdate {
  final String? email;
  final String? name;
  final DateTime? createdAt;

  const UserUpdate({
    this.email,
    this.name,
    this.createdAt,
  });

  Map<String, dynamic> toRow() => {
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (createdAt != null) 'created_at': createdAt,
      };
}

extension UserCopyWith on User {
  User copyWith({
    int? id,
    String? email,
    String? name,
    DateTime? createdAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
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

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'posts',
        columns: [
          SchemaColumn(
              name: 'id',
              type: ColumnType('serial'),
              isPrimaryKey: true,
              isSerial: true),
          SchemaColumn(
              name: 'title', type: ColumnType('text'), nullable: false),
          SchemaColumn(name: 'body', type: ColumnType('text'), nullable: false),
          SchemaColumn(
              name: 'author_id', type: ColumnType('integer'), nullable: false),
          SchemaColumn(
              name: 'created_at',
              type: ColumnType('timestamptz'),
              nullable: false,
              defaultValue: 'now()'),
        ],
        constraints: [
          SchemaConstraint(
              name: 'posts_pkey',
              kind: ConstraintKind.primaryKey,
              columns: ['id']),
          SchemaConstraint(
              name: 'posts_author_id_fkey',
              kind: ConstraintKind.foreignKey,
              columns: ['author_id'],
              referencedTable: 'users',
              referencedColumn: 'id',
              onDelete: 'CASCADE'),
        ],
      );
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

class PostUpdate {
  final String? title;
  final String? body;
  final int? authorId;
  final DateTime? createdAt;

  const PostUpdate({
    this.title,
    this.body,
    this.authorId,
    this.createdAt,
  });

  Map<String, dynamic> toRow() => {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (authorId != null) 'author_id': authorId,
        if (createdAt != null) 'created_at': createdAt,
      };
}

extension PostCopyWith on Post {
  Post copyWith({
    int? id,
    String? title,
    String? body,
    int? authorId,
    DateTime? createdAt,
  }) =>
      Post(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        authorId: authorId ?? this.authorId,
        createdAt: createdAt ?? this.createdAt,
      );
}
