import 'package:stanza/schema.dart';
import 'package:stanza_sqlite/stanza_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteDdl.columnTypeForDart', () {
    test('int → INTEGER', () {
      expect(SqliteDdl.columnTypeForDart('int'), 'INTEGER');
    });

    test('double → REAL', () {
      expect(SqliteDdl.columnTypeForDart('double'), 'REAL');
    });

    test('String → TEXT', () {
      expect(SqliteDdl.columnTypeForDart('String'), 'TEXT');
    });

    test('bool → INTEGER', () {
      expect(SqliteDdl.columnTypeForDart('bool'), 'INTEGER');
    });

    test('DateTime → TEXT', () {
      expect(SqliteDdl.columnTypeForDart('DateTime'), 'TEXT');
    });

    test('serial int → INTEGER', () {
      expect(SqliteDdl.columnTypeForDart('int', isSerial: true), 'INTEGER');
    });

    test('unknown → TEXT', () {
      expect(SqliteDdl.columnTypeForDart('SomeType'), 'TEXT');
    });
  });

  group('SqliteDdl.convertDefault', () {
    test('null → null', () {
      expect(SqliteDdl.convertDefault(null, 'String'), isNull);
    });

    test("now() → datetime('now')", () {
      expect(
        SqliteDdl.convertDefault('now()', 'DateTime'),
        "(datetime('now'))",
      );
    });

    test("NOW() → datetime('now')", () {
      expect(
        SqliteDdl.convertDefault('NOW()', 'DateTime'),
        "(datetime('now'))",
      );
    });

    test('bool true → 1', () {
      expect(SqliteDdl.convertDefault('true', 'bool'), '1');
    });

    test('bool false → 0', () {
      expect(SqliteDdl.convertDefault('false', 'bool'), '0');
    });

    test('string default passes through', () {
      expect(SqliteDdl.convertDefault("'active'", 'String'), "'active'");
    });

    test('numeric default passes through', () {
      expect(SqliteDdl.convertDefault('42', 'int'), '42');
    });
  });

  group('SqliteDdl.resolveColumnType', () {
    test('uses dartTypeName when available', () {
      const col = SchemaColumn(
        name: 'active',
        type: ColumnType('boolean'),
        dartTypeName: 'bool',
      );
      expect(SqliteDdl.resolveColumnType(col), 'INTEGER');
    });

    test('falls back to Postgres type mapping', () {
      const col = SchemaColumn(
        name: 'data',
        type: ColumnType('double precision'),
      );
      expect(SqliteDdl.resolveColumnType(col), 'REAL');
    });

    test('maps serial via dartTypeName', () {
      const col = SchemaColumn(
        name: 'id',
        type: ColumnType('serial'),
        dartTypeName: 'int',
        isSerial: true,
      );
      expect(SqliteDdl.resolveColumnType(col), 'INTEGER');
    });

    test('maps boolean via fallback', () {
      const col = SchemaColumn(
        name: 'active',
        type: ColumnType('boolean'),
      );
      expect(SqliteDdl.resolveColumnType(col), 'INTEGER');
    });

    test('maps timestamptz via fallback', () {
      const col = SchemaColumn(
        name: 'created_at',
        type: ColumnType('timestamptz'),
      );
      expect(SqliteDdl.resolveColumnType(col), 'TEXT');
    });
  });

  group('SqliteDdl.createTable', () {
    test('basic table with serial PK', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            dartTypeName: 'int',
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
          ),
          const SchemaColumn(
            name: 'name',
            type: ColumnType('text'),
            dartTypeName: 'String',
            nullable: false,
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final sql = SqliteDdl.createTable(table);
      expect(sql, contains('CREATE TABLE users'));
      expect(sql, contains('id INTEGER PRIMARY KEY'));
      expect(sql, contains('name TEXT NOT NULL'));
      // Single-column serial PK should not duplicate as table constraint
      expect(sql, isNot(contains('CONSTRAINT users_pkey')));
    });

    test('table with unique and FK constraints', () {
      final table = SchemaTable(
        name: 'posts',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            dartTypeName: 'int',
            isPrimaryKey: true,
            isSerial: true,
          ),
          const SchemaColumn(
            name: 'slug',
            type: ColumnType('text'),
            dartTypeName: 'String',
            nullable: false,
            isUnique: true,
          ),
          const SchemaColumn(
            name: 'author_id',
            type: ColumnType('integer'),
            dartTypeName: 'int',
            nullable: false,
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'posts_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
          const SchemaConstraint(
            name: 'posts_slug_key',
            kind: ConstraintKind.unique,
            columns: ['slug'],
          ),
          const SchemaConstraint(
            name: 'posts_author_id_fkey',
            kind: ConstraintKind.foreignKey,
            columns: ['author_id'],
            referencedTable: 'users',
            referencedColumn: 'id',
            onDelete: 'CASCADE',
          ),
        ],
      );

      final sql = SqliteDdl.createTable(table);
      expect(sql, contains('slug TEXT NOT NULL UNIQUE'));
      expect(sql, contains('CONSTRAINT posts_slug_key UNIQUE (slug)'));
      expect(sql, contains('FOREIGN KEY (author_id) REFERENCES users (id)'));
      expect(sql, contains('ON DELETE CASCADE'));
    });

    test('table with default values', () {
      final table = SchemaTable(
        name: 'items',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            dartTypeName: 'int',
            isPrimaryKey: true,
            isSerial: true,
          ),
          const SchemaColumn(
            name: 'active',
            type: ColumnType('boolean'),
            dartTypeName: 'bool',
            nullable: false,
            defaultValue: 'true',
          ),
          const SchemaColumn(
            name: 'created_at',
            type: ColumnType('timestamptz'),
            dartTypeName: 'DateTime',
            nullable: false,
            defaultValue: 'now()',
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'items_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final sql = SqliteDdl.createTable(table);
      expect(sql, contains('active INTEGER NOT NULL DEFAULT 1'));
      expect(sql, contains("created_at TEXT NOT NULL DEFAULT (datetime('now'))"));
    });

    test('non-serial composite PK uses table constraint', () {
      final table = SchemaTable(
        name: 'join_table',
        columns: [
          const SchemaColumn(
            name: 'user_id',
            type: ColumnType('integer'),
            dartTypeName: 'int',
            nullable: false,
            isPrimaryKey: true,
          ),
          const SchemaColumn(
            name: 'role_id',
            type: ColumnType('integer'),
            dartTypeName: 'int',
            nullable: false,
            isPrimaryKey: true,
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'join_table_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['user_id', 'role_id'],
          ),
        ],
      );

      final sql = SqliteDdl.createTable(table);
      expect(
        sql,
        contains('CONSTRAINT join_table_pkey PRIMARY KEY (user_id, role_id)'),
      );
    });
  });

  group('SqliteDdl.addColumn', () {
    test('basic column', () {
      const col = SchemaColumn(
        name: 'bio',
        type: ColumnType('text'),
        dartTypeName: 'String',
        nullable: false,
      );
      expect(
        SqliteDdl.addColumn('users', col),
        'ALTER TABLE users ADD COLUMN bio TEXT NOT NULL;',
      );
    });

    test('column with default', () {
      const col = SchemaColumn(
        name: 'status',
        type: ColumnType('text'),
        dartTypeName: 'String',
        defaultValue: "'active'",
      );
      expect(
        SqliteDdl.addColumn('users', col),
        "ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active';",
      );
    });

    test('nullable column', () {
      const col = SchemaColumn(
        name: 'notes',
        type: ColumnType('text'),
        dartTypeName: 'String',
      );
      expect(
        SqliteDdl.addColumn('users', col),
        'ALTER TABLE users ADD COLUMN notes TEXT;',
      );
    });
  });

  group('SqliteDdl.generateMigration', () {
    test('CreateTable generates SQLite DDL', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            dartTypeName: 'int',
            isPrimaryKey: true,
            isSerial: true,
          ),
          const SchemaColumn(
            name: 'email',
            type: ColumnType('text'),
            dartTypeName: 'String',
            nullable: false,
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final sql = SqliteDdl.generateMigration([CreateTable(table)]);
      expect(sql, contains('Stanza SQLite migration'));
      expect(sql, contains('BEGIN;'));
      expect(sql, contains('COMMIT;'));
      expect(sql, contains('CREATE TABLE users'));
    });

    test('AddColumn generates SQLite DDL', () {
      const col = SchemaColumn(
        name: 'bio',
        type: ColumnType('text'),
        dartTypeName: 'String',
      );
      final sql = SqliteDdl.generateMigration(
        [const AddColumn('users', col)],
      );
      expect(sql, contains('ALTER TABLE users ADD COLUMN bio TEXT;'));
    });

    test('DropColumn is commented for safety', () {
      final sql = SqliteDdl.generateMigration(
        [const DropColumn('users', 'old_col')],
      );
      expect(sql, contains('-- SAFETY'));
      expect(sql, contains('DROP COLUMN old_col'));
    });

    test('unsupported ops produce TODO comments', () {
      final ops = [
        const AlterColumnType('users', 'data', 'jsonb'),
        const AlterColumnNullability('users', 'name', false),
        const AlterColumnDefault('users', 'status', "'active'"),
        const AddConstraint(
          'users',
          SchemaConstraint(
            name: 'users_email_key',
            kind: ConstraintKind.unique,
            columns: ['email'],
          ),
        ),
        const DropConstraint('users', 'users_old_key'),
      ];

      final sql = SqliteDdl.generateMigration(ops);
      expect(sql, contains('-- TODO: ALTER COLUMN users.data TYPE change'));
      expect(
        sql,
        contains('-- TODO: ALTER COLUMN users.name nullability change'),
      );
      expect(
        sql,
        contains('-- TODO: ALTER COLUMN users.status default change'),
      );
      expect(
        sql,
        contains('-- TODO: ADD CONSTRAINT users_email_key'),
      );
      expect(
        sql,
        contains('-- TODO: DROP CONSTRAINT users_old_key'),
      );
    });
  });
}
