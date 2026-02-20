import 'package:stanza/schema.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaDiff.diff', () {
    test('new table → CreateTable', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
          ),
          const SchemaColumn(name: 'name', type: ColumnType('text')),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, null);
      expect(ops, hasLength(1));
      expect(ops.first, isA<CreateTable>());
    });

    test('identical tables → no ops', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('integer'),
            nullable: false,
          ),
        ],
      );

      final ops = SchemaDiff.diff(table, table);
      expect(ops, isEmpty);
    });

    test('new column → AddColumn', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AddColumn>());
      final add = ops.first as AddColumn;
      expect(add.column.name, 'email');
    });

    test('type change → AlterColumnType', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'data', type: ColumnType('jsonb')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'data', type: ColumnType('text')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnType>());
      expect((ops.first as AlterColumnType).newType, 'jsonb');
    });

    test('serial ≡ integer produces no type change', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            isSerial: true,
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('integer'),
            isSerial: true,
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, isEmpty);
    });

    test('nullability change → AlterColumnNullability', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'name',
            type: ColumnType('text'),
            nullable: false,
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'name', type: ColumnType('text')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnNullability>());
      expect((ops.first as AlterColumnNullability).nullable, isFalse);
    });

    test('default change → AlterColumnDefault', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'status',
            type: ColumnType('text'),
            defaultValue: "'active'",
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'status', type: ColumnType('text')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnDefault>());
      expect((ops.first as AlterColumnDefault).newDefault, "'active'");
    });

    test('serial column skips default diff', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            isSerial: true,
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('integer'),
            isSerial: true,
            defaultValue: "nextval('users_id_seq')",
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, isEmpty);
    });

    test('removed column → DropColumn (commented)', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'old_col', type: ColumnType('text')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<DropColumn>());
      expect(ops.first.toSql(), contains('-- SAFETY'));
    });

    test('new constraint → AddConstraint', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_email_key',
            kind: ConstraintKind.unique,
            columns: ['email'],
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AddConstraint>());
    });

    test('removed constraint → DropConstraint', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_email_key',
            kind: ConstraintKind.unique,
            columns: ['email'],
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<DropConstraint>());
    });

    test('multiple changes combined', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
          const SchemaColumn(name: 'name', type: ColumnType('varchar(50)')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('varchar(100)')),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(2)); // type change + new column
      expect(ops[0], isA<AlterColumnType>()); // email type changed
      expect(ops[1], isA<AddColumn>()); // name is new
    });
  });

  group('SchemaDiffOp.toSql', () {
    test('CreateTable generates full DDL', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            nullable: false,
          ),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final sql = CreateTable(table).toSql();
      expect(sql, contains('CREATE TABLE users'));
      expect(sql, contains('id serial NOT NULL'));
      expect(sql, contains('email text'));
      expect(sql, contains('CONSTRAINT users_pkey PRIMARY KEY (id)'));
    });

    test('AddColumn generates ALTER TABLE', () {
      const col =
          SchemaColumn(name: 'bio', type: ColumnType('text'), nullable: false);
      expect(
        const AddColumn('users', col).toSql(),
        'ALTER TABLE users ADD COLUMN bio text NOT NULL;',
      );
    });

    test('AddColumn with default', () {
      const col = SchemaColumn(
        name: 'status',
        type: ColumnType('text'),
        defaultValue: "'active'",
      );
      expect(
        const AddColumn('users', col).toSql(),
        "ALTER TABLE users ADD COLUMN status text DEFAULT 'active';",
      );
    });

    test('AlterColumnType', () {
      expect(
        const AlterColumnType('users', 'data', 'jsonb').toSql(),
        'ALTER TABLE users ALTER COLUMN data TYPE jsonb;',
      );
    });

    test('AlterColumnNullability SET NOT NULL', () {
      expect(
        const AlterColumnNullability('users', 'name', false).toSql(),
        'ALTER TABLE users ALTER COLUMN name SET NOT NULL;',
      );
    });

    test('AlterColumnNullability DROP NOT NULL', () {
      expect(
        const AlterColumnNullability('users', 'name', true).toSql(),
        'ALTER TABLE users ALTER COLUMN name DROP NOT NULL;',
      );
    });

    test('AlterColumnDefault SET', () {
      expect(
        const AlterColumnDefault('users', 'status', "'active'").toSql(),
        "ALTER TABLE users ALTER COLUMN status SET DEFAULT 'active';",
      );
    });

    test('AlterColumnDefault DROP', () {
      expect(
        const AlterColumnDefault('users', 'status', null).toSql(),
        'ALTER TABLE users ALTER COLUMN status DROP DEFAULT;',
      );
    });

    test('DropColumn is commented for safety', () {
      final sql = const DropColumn('users', 'old_col').toSql();
      expect(sql, startsWith('-- SAFETY'));
      expect(sql, contains('DROP COLUMN old_col'));
    });

    test('DropConstraint', () {
      expect(
        const DropConstraint('users', 'users_email_key').toSql(),
        'ALTER TABLE users DROP CONSTRAINT users_email_key;',
      );
    });

    test('AddConstraint PK', () {
      expect(
        const AddConstraint(
          'users',
          SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ).toSql(),
        'ALTER TABLE users ADD CONSTRAINT users_pkey PRIMARY KEY (id);',
      );
    });

    test('AddConstraint UNIQUE', () {
      expect(
        const AddConstraint(
          'users',
          SchemaConstraint(
            name: 'users_email_key',
            kind: ConstraintKind.unique,
            columns: ['email'],
          ),
        ).toSql(),
        'ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE (email);',
      );
    });

    test('AddConstraint FK', () {
      final sql = const AddConstraint(
        'posts',
        SchemaConstraint(
          name: 'posts_author_id_fkey',
          kind: ConstraintKind.foreignKey,
          columns: ['author_id'],
          referencedTable: 'users',
          referencedColumn: 'id',
          onDelete: 'CASCADE',
        ),
      ).toSql();
      expect(sql, contains('FOREIGN KEY (author_id)'));
      expect(sql, contains('REFERENCES users (id)'));
      expect(sql, contains('ON DELETE CASCADE'));
    });

    test('AddConstraint FK without onDelete', () {
      final sql = const AddConstraint(
        'posts',
        SchemaConstraint(
          name: 'posts_author_id_fkey',
          kind: ConstraintKind.foreignKey,
          columns: ['author_id'],
          referencedTable: 'users',
          referencedColumn: 'id',
        ),
      ).toSql();
      expect(sql, contains('FOREIGN KEY (author_id)'));
      expect(sql, isNot(contains('ON DELETE')));
    });
  });

  group('SchemaTable helpers', () {
    test('columnByName finds column', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
      );
      expect(table.columnByName('email')?.name, 'email');
      expect(table.columnByName('missing'), isNull);
    });

    test('constraint naming conventions', () {
      final table = SchemaTable(name: 'users', columns: []);
      expect(table.primaryKeyConstraintName, 'users_pkey');
      expect(table.uniqueConstraintName('email'), 'users_email_key');
      expect(table.foreignKeyConstraintName('post_id'), 'users_post_id_fkey');
    });
  });
}
