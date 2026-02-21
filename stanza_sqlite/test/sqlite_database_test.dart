import 'package:stanza/stanza.dart';
import 'package:stanza_sqlite/stanza_sqlite.dart';
import 'package:test/test.dart';

// Minimal table descriptor for testing (mirrors generated code pattern)
class _TestUser {
  final int id;
  final String name;
  final bool active;
  final DateTime createdAt;

  _TestUser({
    required this.id,
    required this.name,
    required this.active,
    required this.createdAt,
  });
}

class _TestUserTable extends TableDescriptor<_TestUser> {
  @override
  String get tableName => 'test_users';

  final id = const IntColumn('id', 'test_users');
  final name = const StringColumn('name', 'test_users');
  final active = const BoolColumn('active', 'test_users');
  final createdAt = const DateTimeColumn('created_at', 'test_users');

  @override
  List<Column> get columns => [id, name, active, createdAt];

  @override
  Column get primaryKey => id;

  @override
  _TestUser fromRow(Map<String, dynamic> row) => _TestUser(
        id: row['id'] as int,
        name: row['name'] as String,
        active: row['active'] as bool,
        createdAt: row['created_at'] as DateTime,
      );

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'test_users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            dartTypeName: 'int',
            isPrimaryKey: true,
            isSerial: true,
          ),
          const SchemaColumn(
            name: 'name',
            type: ColumnType('text'),
            dartTypeName: 'String',
            nullable: false,
          ),
          const SchemaColumn(
            name: 'active',
            type: ColumnType('boolean'),
            dartTypeName: 'bool',
            nullable: false,
          ),
          const SchemaColumn(
            name: 'created_at',
            type: ColumnType('timestamptz'),
            dartTypeName: 'DateTime',
            nullable: false,
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'test_users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );
}

void main() {
  late StanzaSqlite db;
  final userTable = _TestUserTable();

  setUp(() {
    db = StanzaSqlite.memory();
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper: create the test_users table directly
  Future<void> createTestTable() async {
    await db.rawExecute('''
      CREATE TABLE test_users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        active INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  group('StanzaSqlite connection', () {
    test('opens in-memory database', () async {
      // Should not throw
      await db.rawExecute('SELECT 1');
    });

    test('foreign keys enabled by default', () async {
      final result = await db.rawQuery(
        'PRAGMA foreign_keys',
        mapper: (row) => row['foreign_keys'],
      );
      expect(result.first, 1);
    });

    test('createParameterCollector uses : prefix', () {
      final params = db.createParameterCollector();
      final placeholder = params.add('test');
      expect(placeholder, ':p0');
    });
  });

  group('StanzaSqlite.rawExecute', () {
    test('executes DDL', () async {
      await createTestTable();

      // Verify table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='test_users'",
        mapper: (row) => row['name'] as String,
      );
      expect(result, ['test_users']);
    });

    test('executes INSERT with parameters', () async {
      await createTestTable();
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:name, :active, :created_at)',
        parameters: {
          'name': 'Alice',
          'active': true,
          'created_at': DateTime.utc(2024, 1, 15),
        },
      );

      final rows = await db.rawQuery(
        'SELECT * FROM test_users',
        mapper: (row) => row,
      );
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'Alice');
      expect(rows.first['active'], 1); // bool stored as int
      expect(rows.first['created_at'], isA<String>()); // DateTime stored as text
    });

    test('returns rows for SELECT', () async {
      await createTestTable();
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:name, :active, :created_at)',
        parameters: {
          'name': 'Bob',
          'active': false,
          'created_at': DateTime.utc(2024, 6, 1),
        },
      );

      final result = await db.rawExecute(
        'SELECT name, active FROM test_users WHERE name = :name',
        parameters: {'name': 'Bob'},
      );
      expect(result.rows, hasLength(1));
      expect(result.rows.first['name'], 'Bob');
      expect(result.rows.first['active'], 0);
    });
  });

  group('Type conversion', () {
    test('bool round-trip: true → 1 → true', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 3, 10);
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:name, :active, :created_at)',
        parameters: {'name': 'Alice', 'active': true, 'created_at': now},
      );

      final result = await db.execute(
        SelectQuery<_TestUser, _TestUserTable>(userTable)
            .where((t) => t.name.equals('Alice')),
      );
      expect(result.entities.first.active, isTrue);
    });

    test('bool round-trip: false → 0 → false', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 3, 10);
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:name, :active, :created_at)',
        parameters: {'name': 'Bob', 'active': false, 'created_at': now},
      );

      final result = await db.execute(
        SelectQuery<_TestUser, _TestUserTable>(userTable)
            .where((t) => t.name.equals('Bob')),
      );
      expect(result.entities.first.active, isFalse);
    });

    test('DateTime round-trip: object → ISO 8601 → object', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 7, 4, 12, 30, 45);
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:name, :active, :created_at)',
        parameters: {'name': 'Carol', 'active': true, 'created_at': now},
      );

      final result = await db.execute(
        SelectQuery<_TestUser, _TestUserTable>(userTable)
            .where((t) => t.name.equals('Carol')),
      );
      expect(result.entities.first.createdAt, now);
    });

    test('null handling for nullable columns', () async {
      await db.rawExecute('''
        CREATE TABLE nullable_test (
          id INTEGER PRIMARY KEY,
          note TEXT
        )
      ''');
      await db.rawExecute(
        'INSERT INTO nullable_test (note) VALUES (NULL)',
      );
      final result = await db.rawQuery(
        'SELECT * FROM nullable_test',
        mapper: (row) => row['note'],
      );
      expect(result.first, isNull);
    });
  });

  group('StanzaSqlite.execute (typed query)', () {
    test('SELECT returns mapped entities', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 1, 1);
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:n, :a, :c)',
        parameters: {'n': 'Dave', 'a': true, 'c': now},
      );

      final query = SelectQuery<_TestUser, _TestUserTable>(userTable);
      final result = await db.execute(query);

      expect(result.entities, hasLength(1));
      final user = result.entities.first;
      expect(user.name, 'Dave');
      expect(user.active, isTrue);
      expect(user.createdAt, now);
    });

    test('empty result returns empty entities', () async {
      await createTestTable();
      final query = SelectQuery<_TestUser, _TestUserTable>(userTable);
      final result = await db.execute(query);
      expect(result.isEmpty, isTrue);
      expect(result.entities, isEmpty);
    });
  });

  group('StanzaSqlite.transaction', () {
    test('commits on success', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 1, 1);

      await db.transaction((tx) async {
        await tx.rawExecute(
          'INSERT INTO test_users (name, active, created_at) VALUES (:n, :a, :c)',
          parameters: {'n': 'Eve', 'a': true, 'c': now},
        );
      });

      final result = await db.rawQuery(
        'SELECT name FROM test_users',
        mapper: (row) => row['name'] as String,
      );
      expect(result, ['Eve']);
    });

    test('rolls back on error', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 1, 1);

      try {
        await db.transaction((tx) async {
          await tx.rawExecute(
            'INSERT INTO test_users (name, active, created_at) VALUES (:n, :a, :c)',
            parameters: {'n': 'Frank', 'a': true, 'c': now},
          );
          throw Exception('Abort!');
        });
      } catch (_) {}

      final result = await db.rawQuery(
        'SELECT name FROM test_users',
        mapper: (row) => row['name'] as String,
      );
      expect(result, isEmpty);
    });
  });

  group('StanzaSqlite.run', () {
    test('executes block on session', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 1, 1);

      await db.run((session) async {
        await session.rawExecute(
          'INSERT INTO test_users (name, active, created_at) VALUES (:n, :a, :c)',
          parameters: {'n': 'Grace', 'a': false, 'c': now},
        );
      });

      final result = await db.rawQuery(
        'SELECT name FROM test_users',
        mapper: (row) => row['name'] as String,
      );
      expect(result, ['Grace']);
    });
  });

  group('StanzaSqlite.rawQuery', () {
    test('maps results using custom mapper', () async {
      await createTestTable();
      final now = DateTime.utc(2024, 1, 1);
      await db.rawExecute(
        'INSERT INTO test_users (name, active, created_at) VALUES (:n, :a, :c)',
        parameters: {'n': 'Hank', 'a': true, 'c': now},
      );

      final names = await db.rawQuery(
        'SELECT name FROM test_users',
        mapper: (row) => row['name'] as String,
      );
      expect(names, ['Hank']);
    });
  });
}
