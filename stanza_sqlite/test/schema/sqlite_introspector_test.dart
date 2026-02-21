import 'package:stanza/stanza.dart';
import 'package:stanza_sqlite/stanza_sqlite.dart';
import 'package:test/test.dart';

void main() {
  late StanzaSqlite db;
  late SqliteIntrospector introspector;

  setUp(() {
    db = StanzaSqlite.memory();
    introspector = SqliteIntrospector(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SqliteIntrospector.introspect', () {
    test('empty table list returns empty map', () async {
      final result = await introspector.introspect([]);
      expect(result, isEmpty);
    });

    test('non-existent table returns null', () async {
      final result = await introspector.introspect(['nonexistent']);
      expect(result['nonexistent'], isNull);
    });

    test('introspects basic table columns', () async {
      await db.rawExecute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT
        )
      ''');

      final result = await introspector.introspect(['users']);
      final table = result['users']!;

      expect(table.name, 'users');
      expect(table.columns, hasLength(3));

      final idCol = table.columnByName('id')!;
      expect(idCol.isPrimaryKey, isTrue);
      expect(idCol.isSerial, isTrue);

      final nameCol = table.columnByName('name')!;
      expect(nameCol.nullable, isFalse);

      final emailCol = table.columnByName('email')!;
      expect(emailCol.nullable, isTrue);
    });

    test('detects column types', () async {
      await db.rawExecute('''
        CREATE TABLE typed (
          id INTEGER PRIMARY KEY,
          score REAL NOT NULL,
          label TEXT NOT NULL
        )
      ''');

      final result = await introspector.introspect(['typed']);
      final table = result['typed']!;

      final score = table.columnByName('score')!;
      expect(score.type.value, 'double precision');

      final label = table.columnByName('label')!;
      expect(label.type.value, 'text');
    });

    test('detects default values', () async {
      await db.rawExecute('''
        CREATE TABLE defaults_test (
          id INTEGER PRIMARY KEY,
          status TEXT NOT NULL DEFAULT 'active',
          count INTEGER NOT NULL DEFAULT 0
        )
      ''');

      final result = await introspector.introspect(['defaults_test']);
      final table = result['defaults_test']!;

      final status = table.columnByName('status')!;
      expect(status.defaultValue, "'active'");

      final count = table.columnByName('count')!;
      expect(count.defaultValue, '0');
    });

    test('detects unique constraints', () async {
      await db.rawExecute('''
        CREATE TABLE unique_test (
          id INTEGER PRIMARY KEY,
          email TEXT NOT NULL UNIQUE
        )
      ''');

      final result = await introspector.introspect(['unique_test']);
      final table = result['unique_test']!;

      final emailCol = table.columnByName('email')!;
      expect(emailCol.isUnique, isTrue);

      // Should have a unique constraint
      final uniqueConstraints = table.constraints
          .where((c) => c.kind == ConstraintKind.unique)
          .toList();
      expect(uniqueConstraints, hasLength(1));
    });

    test('detects PK constraint', () async {
      await db.rawExecute('''
        CREATE TABLE pk_test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');

      final result = await introspector.introspect(['pk_test']);
      final table = result['pk_test']!;

      final pkConstraints = table.constraints
          .where((c) => c.kind == ConstraintKind.primaryKey)
          .toList();
      expect(pkConstraints, hasLength(1));
      expect(pkConstraints.first.columns, ['id']);
    });

    test('detects foreign key constraints', () async {
      await db.rawExecute('''
        CREATE TABLE authors (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      await db.rawExecute('''
        CREATE TABLE books (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE
        )
      ''');

      final result = await introspector.introspect(['books']);
      final table = result['books']!;

      final fkConstraints = table.constraints
          .where((c) => c.kind == ConstraintKind.foreignKey)
          .toList();
      expect(fkConstraints, hasLength(1));
      expect(fkConstraints.first.columns, ['author_id']);
      expect(fkConstraints.first.referencedTable, 'authors');
      expect(fkConstraints.first.referencedColumn, 'id');
      expect(fkConstraints.first.onDelete, 'CASCADE');
    });

    test('FK with NO ACTION has null onDelete', () async {
      await db.rawExecute(
        'CREATE TABLE parents (id INTEGER PRIMARY KEY)',
      );
      await db.rawExecute('''
        CREATE TABLE children (
          id INTEGER PRIMARY KEY,
          parent_id INTEGER REFERENCES parents(id)
        )
      ''');

      final result = await introspector.introspect(['children']);
      final table = result['children']!;

      final fk = table.constraints
          .firstWhere((c) => c.kind == ConstraintKind.foreignKey);
      expect(fk.onDelete, isNull);
    });

    test('introspects multiple tables', () async {
      await db.rawExecute(
        'CREATE TABLE a (id INTEGER PRIMARY KEY, name TEXT)',
      );
      await db.rawExecute(
        'CREATE TABLE b (id INTEGER PRIMARY KEY, label TEXT)',
      );

      final result = await introspector.introspect(['a', 'b', 'missing']);
      expect(result['a'], isNotNull);
      expect(result['b'], isNotNull);
      expect(result['missing'], isNull);
    });

    test('serial detection: INTEGER PRIMARY KEY is serial', () async {
      await db.rawExecute('''
        CREATE TABLE serial_test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');

      final result = await introspector.introspect(['serial_test']);
      final idCol = result['serial_test']!.columnByName('id')!;
      expect(idCol.isSerial, isTrue);
      expect(idCol.defaultValue, isNull);
    });
  });
}
