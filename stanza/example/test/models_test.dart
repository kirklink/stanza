import 'package:stanza/stanza.dart';
import 'package:stanza_example/src/models.dart';
import 'package:test/test.dart';

void main() {
  late $UserTable users;
  late $PostTable posts;

  setUp(() {
    users = $UserTable();
    posts = $PostTable();
  });

  group('generated table descriptor', () {
    test('table name is pluralized snake_case', () {
      expect(users.tableName, 'users');
      expect(posts.tableName, 'posts');
    });

    test('columns are typed', () {
      expect(users.id, isA<IntColumn>());
      expect(users.email, isA<StringColumn>());
      expect(users.createdAt, isA<DateTimeColumn>());
      expect(posts.authorId, isA<IntColumn>());
    });

    test('column names are snake_case', () {
      expect(users.createdAt.name, 'created_at');
      expect(posts.authorId.name, 'author_id');
    });

    test('fromRow maps correctly', () {
      final now = DateTime.now();
      final user = users.fromRow({
        'id': 1,
        'email': 'test@test.com',
        'name': 'Kirk',
        'created_at': now,
      });
      expect(user.id, 1);
      expect(user.email, 'test@test.com');
      expect(user.name, 'Kirk');
      expect(user.createdAt, now);
    });
  });

  group('generated insert companion', () {
    test('excludes auto-increment PK', () {
      final insert = UserInsert(email: 'a@b.com', name: 'Test');
      final row = insert.toRow();
      expect(row.containsKey('id'), isFalse);
      expect(row, {'email': 'a@b.com', 'name': 'Test'});
    });

    test('includes optional field when provided', () {
      final now = DateTime(2025, 1, 1);
      final insert = UserInsert(email: 'a@b.com', name: 'Test', createdAt: now);
      expect(insert.toRow(), {'email': 'a@b.com', 'name': 'Test', 'created_at': now});
    });

    test('omits optional field when null', () {
      final insert = UserInsert(email: 'a@b.com', name: 'Test');
      expect(insert.toRow().containsKey('created_at'), isFalse);
    });
  });

  group('generated update companion', () {
    test('includes only set fields', () {
      final update = UserUpdate(name: 'New');
      expect(update.toRow(), {'name': 'New'});
    });

    test('excludes primary key', () {
      // UserUpdate doesn't have an id field at all
      final update = UserUpdate(email: 'x@y.com', name: 'Y');
      expect(update.toRow().containsKey('id'), isFalse);
    });
  });

  group('generated copyWith', () {
    test('copies with changed fields', () {
      final now = DateTime.now();
      final user = User(id: 1, email: 'a@b.com', name: 'Kirk', createdAt: now);
      final updated = user.copyWith(name: 'Spock');
      expect(updated.name, 'Spock');
      expect(updated.id, 1);
      expect(updated.email, 'a@b.com');
    });
  });

  group('generated \$schema', () {
    test('users schema has correct table name and columns', () {
      final schema = users.$schema;
      expect(schema, isNotNull);
      expect(schema.name, 'users');
      expect(schema.columns, hasLength(4));
      expect(schema.columns.map((c) => c.name), ['id', 'email', 'name', 'created_at']);
    });

    test('users PK is serial', () {
      final idCol = users.$schema.columns.first;
      expect(idCol.isPrimaryKey, isTrue);
      expect(idCol.isSerial, isTrue);
      expect(idCol.type.value, 'serial');
    });

    test('users email has unique constraint and varchar type', () {
      final emailCol = users.$schema.columnByName('email')!;
      expect(emailCol.isUnique, isTrue);
      expect(emailCol.type.value, 'varchar(100)');
      expect(emailCol.nullable, isFalse);
    });

    test('users has PK and unique constraints', () {
      final constraints = users.$schema.constraints;
      expect(constraints.any((c) => c.kind == ConstraintKind.primaryKey), isTrue);
      expect(constraints.any(
        (c) => c.kind == ConstraintKind.unique && c.columns.contains('email'),
      ), isTrue);
    });

    test('posts has FK constraint to users', () {
      final fk = posts.$schema.constraints.firstWhere(
        (c) => c.kind == ConstraintKind.foreignKey,
      );
      expect(fk.columns, ['author_id']);
      expect(fk.referencedTable, 'users');
      expect(fk.referencedColumn, 'id');
      expect(fk.onDelete, 'CASCADE');
    });

    test('posts created_at has default value', () {
      final col = posts.$schema.columnByName('created_at')!;
      expect(col.defaultValue, 'now()');
    });
  });

  group('queries with generated types', () {
    test('select with typed where', () {
      final params = ParameterCollector();
      final q = SelectQuery(users)
          .where((t) => t.email.like('%@example.com'))
          .orderBy((t) => t.createdAt.desc())
          .limit(10);
      expect(
        q.toSql(params),
        'SELECT users.* FROM users '
        'WHERE users.email LIKE @p0 '
        'ORDER BY users.created_at DESC '
        'LIMIT 10',
      );
    });

    test('insert from companion', () {
      final params = ParameterCollector();
      final q = InsertQuery(users)
          .values(UserInsert(email: 'test@test.com', name: 'Kirk').toRow())
          .returning();
      expect(
        q.toSql(params),
        'INSERT INTO users (email, name) VALUES (@p0, @p1) RETURNING *',
      );
    });

    test('update from companion with where', () {
      final params = ParameterCollector();
      final q = UpdateQuery(users, UserUpdate(name: 'New').toRow())
          .where((t) => t.id.equals(1));
      expect(
        q.toSql(params),
        'UPDATE users SET name = @p0 WHERE users.id = @p1',
      );
    });

    test('join posts to users', () {
      final params = ParameterCollector();
      final q = SelectQuery(posts).innerJoin(
        users,
        (p, u) => p.authorId.equalsColumn(u.id),
      );
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'INNER JOIN users ON posts.author_id = users.id',
      );
    });
  });
}
