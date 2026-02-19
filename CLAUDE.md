# Stanza - Dart PostgreSQL Query Builder

Type-safe PostgreSQL query builder with code generation and schema management. Fluent API for SELECT, INSERT, UPDATE, DELETE with parameterized queries, JOINs, RETURNING, streaming, full-text search, trigram similarity, and typed result mapping. Forward-only migration system with schema diffing.

## Project Structure

- `stanza/` - Runtime library (query builder, connection management, result types, schema management)
- `stanza_builder/` - Code generator (source_gen/build_runner, reads annotations → generates Table classes with `$schema`)
- `stanza/example/` - Example entity definitions with generated code + migration CLI script
- `docs/assessment/stanza-modernized/ROADMAP.md` - Implementation roadmap (all phases complete)

## Branch Strategy

- `main` - Stable code
- `dev` - All features merged (active)
- `feature/modernization` - Core query builder (complete, merged to dev)
- `feature/schema-management` - Schema management & migrations (complete, merged to dev)

## Commands

```bash
# Run tests (from stanza/stanza/)
dart test

# Analyze (from stanza/stanza/ or stanza/stanza_builder/)
dart analyze

# Regenerate example code (from stanza/stanza/example/)
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

### Two Packages

1. **stanza** (runtime) - Query classes, connection pool (postgres v3), result mapping, schema management (`lib/src/schema/`)
2. **stanza_builder** (codegen) - source_gen generator reads `@StanzaEntity`/`@StanzaField`/`@PrimaryKey`/`@BelongsTo` annotations, generates typed `Table<T>` subclasses with `Field` accessors, `fromDb()`, `toDb()`, `$schema`, and JOIN helpers

### Key Patterns

- **Mixin composition**: `WhereClause` and `ReturningClause` are mixins on `Query`, shared across query types
- **Parameterized queries**: All user values go through named parameters (`@name`) to prevent SQL injection
- **Safe by default**: UPDATE/DELETE require WHERE clause unless `overrideSafety: true`
- **Connection pooling**: postgres v3 `Pool` with instance caching by connection key
- **Fluent builder**: Method chaining for query construction

### Build Configuration (stanza_builder/build.yaml)

- `build_to: cache`, builder name `stanza_entity`, applies `combining_builder`
- Output: `.stanza.g.part` files

## Key Files

| File | Purpose |
|------|---------|
| `stanza/lib/src/stanza.dart` | Stanza/StanzaSession classes (pool, execute, transactions, streaming) |
| `stanza/lib/src/annotations.dart` | @StanzaEntity, @StanzaField, @PrimaryKey, @BelongsTo |
| `stanza/lib/src/table.dart` | Abstract Table<T> with fromDb/toDb/$schema |
| `stanza/lib/src/field.dart` | Field class with aggregates (sum, avg, count, min, max) |
| `stanza/lib/src/select/select_query.dart` | SelectQuery (joins, groupBy, orderBy, limit, offset, FTS rank/headline, similarity) |
| `stanza/lib/src/insert/insert_query.dart` | InsertQuery (single, batch, upsert) |
| `stanza/lib/src/update/update_query.dart` | UpdateQuery with SetValue (.string, .number, etc.) |
| `stanza/lib/src/delete/delete_query.dart` | DeleteQuery |
| `stanza/lib/src/shared/where_clause.dart` | WhereClause mixin (where/and/or) |
| `stanza/lib/src/shared/where_operations.dart` | WhereOperation (20+ comparison operators + FTS + trigram) |
| `stanza/lib/src/shared/fts_config.dart` | FtsConfig enum (language configs) + FtsQueryType enum |
| `stanza/lib/src/shared/returning_clause.dart` | ReturningClause mixin (returning/returningStar) |
| `stanza/lib/src/select/join_clause.dart` | JoinClause (inner, left, right, cross) |
| `stanza/lib/src/schema/column_type.dart` | PG type mapping + equivalence (serial ≡ integer) |
| `stanza/lib/src/schema/schema_column.dart` | Column definition (type, nullable, PK, serial, unique, default) |
| `stanza/lib/src/schema/schema_constraint.dart` | Constraint (PK, UNIQUE, FK with onDelete) |
| `stanza/lib/src/schema/schema_table.dart` | Table = columns + constraints |
| `stanza/lib/src/schema/schema_diff.dart` | Sealed SchemaDiffOp hierarchy + SchemaDiff.diff() |
| `stanza/lib/src/schema/db_introspector.dart` | Queries information_schema for actual DB state |
| `stanza/lib/src/schema/migration_file.dart` | Generates timestamped .sql migration files |
| `stanza/lib/src/schema/migration_runner.dart` | Applies migrations, tracks in _stanza_migrations |
| `stanza/lib/src/schema/schema_manager.dart` | Orchestrator: diff → generate → apply |
| `stanza/lib/src/schema/stanza_cli.dart` | CLI helper (status/diff/generate/apply) |
| `stanza_builder/lib/src/stanza_entity_generator.dart` | Main code generator (emits $schema getter) |

## Tests

- 271 tests across 14 test files in `stanza/stanza/test/`
- Unit tests cover all query types, WHERE operations, JOINs, RETURNING, field aggregates, FTS, trigram similarity, streaming, schema model, diff engine, migration file generation
- Schema tests in `test/schema/`: `column_type_test.dart`, `schema_diff_test.dart`, `migration_file_test.dart`
- Integration tests in `integration_test.dart` require `DATABASE_URL` env var (Neon PostgreSQL); skipped gracefully when not set
- Test helpers in `test_helpers.dart` define mock `AnimalTable`, `OwnerTable`, `HabitatTable`

## API Quick Reference

### Connection

```dart
// From URL (Neon, Supabase, etc.)
final stanza = Stanza.url('postgresql://user:pass@host/db?sslmode=require');

// From credentials with connection config
final stanza = Stanza.tcp(
  PostgresCredentials('host', 5432, 'db', 'user', 'pass'),
  maxConnections: 10,
  sslMode: SslMode.require,
  connectTimeout: Duration(seconds: 15),
  queryTimeout: Duration(seconds: 30),
  applicationName: 'my-app',
);

// Raw SQL (DDL, migrations)
await stanza.rawExecute('CREATE TABLE ...');

// Transactions
await stanza.runTransaction((session) async {
  await session.execute(insertQuery);
  return session.execute(selectQuery);
});
```

### SELECT

```dart
final q = SelectQuery(Animal.$table)
  ..selectStar()
  ..where(Animal.$table.color).matches('orange')
  ..and(Animal.$table.legs).isGreaterThan(2)
  ..orderBy(Animal.$table.name)
  ..limit(10);

// DISTINCT:
final q = SelectQuery(Animal.$table)
  ..distinct()
  ..selectFields([Animal.$table.color]);

// GROUP BY + HAVING:
final q = SelectQuery(Animal.$table)
  ..selectFields([Animal.$table.color, Animal.$table.id..count()..rename('count')])
  ..groupBy([Animal.$table.color])
  ..having(Animal.$table.id..count()).isGreaterThan(2)
  ..andHaving(Animal.$table.id..count()).isLessThan(100);
```

### INSERT

```dart
// Single entity:
final q = InsertQuery(Animal.$table)
  ..insertEntity(animal)
  ..returningStar();

// Batch insert:
final q = InsertQuery(Animal.$table)
  ..insertEntities<Animal>([tiger, eagle, snake])
  ..returningStar();

// Upsert (ON CONFLICT DO UPDATE):
final q = InsertQuery(Animal.$table)
  ..insertEntity(animal)
  ..onConflict(
    target: [Animal.$table.name],
    doUpdate: (set) => set
      ..column(Animal.$table.color).string('updated')
      ..column(Animal.$table.legs).integer(4),
  )
  ..returningStar();

// ON CONFLICT DO NOTHING:
final q = InsertQuery(Animal.$table)
  ..insertEntity(animal)
  ..onConflictDoNothing(target: [Animal.$table.name]);
```

### UPDATE

```dart
final q = UpdateQuery(Animal.$table)
  ..column(Animal.$table.color).string('white')
  ..column(Animal.$table.legs).integer(4)
  ..where(Animal.$table.id).isEqualTo(1)
  ..returningStar();
```

### DELETE

```dart
final q = DeleteQuery(Animal.$table)
  ..where(Animal.$table.id).isEqualTo(1)
  ..returningStar();
```

### WHERE Operations

- **Numeric**: `isEqualTo(num)`, `isGreaterThan(num)`, `isGreaterThanOrEqualTo(num)`, `isLessThan(num)`, `isLessThanOrEqualTo(num)`
- **String**: `matches(String, {caseSensitive})`, `startsWith(String)`, `endsWith(String)`, `contains(String)`
- **Set membership**: `isIn(List<Object>)`, `isNotIn(List<Object>)`
- **Range**: `isBetween(Object low, Object high)`
- **Boolean**: `isTrue()`, `isFalse()`
- **Null**: `isNull()`, `isNotNull()`
- **DateTime**: `isBefore(DateTime)`, `isAfter(DateTime)`, `isOn(DateTime)`
- **Full-text search**: `fullTextMatches(String, {FtsConfig, FtsQueryType})` — `to_tsvector() @@ tsquery()`
- **Trigram similarity**: `isSimilarTo(String)` — `field % @param`, `isWordSimilarTo(String)` — `@param %> field`
- **Raw**: `raw(String sql)` for custom SQL conditions

**Note**: `isEqualTo()` only accepts `num`, not `String`. Use `matches()` for string equality.

### JOINs

```dart
final q = SelectQuery(Animal.$table)..selectStar();
Animal.$table.innerJoinOwner(q); // Generated typed JOIN helper
q.where(Owner.$table.name).matches('alice');

// Or manual:
q.innerJoin(Owner.$table).on(Animal.$table.ownerId, Owner.$table.id);
```

### SetValue Types (UpdateQuery)

`column(field).string('v')`, `.number(1.5)`, `.integer(1)`, `.float(1.5)`, `.boolean(true)`, `.datetime(dt)`, `.any(val)`

### OrderBy

```dart
q.orderBy(field);                      // ASC
q.orderBy(field, descending: true);    // DESC
```

### Annotations (for code generation)

```dart
@StanzaEntity(name: 'table_name', snakeCase: true, readOnly: false)
class MyEntity {
  @PrimaryKey()                  // serial PK (auto-increment)
  @StanzaField(readOnly: true)   // exclude from writes
  late int id;

  @StanzaField(name: 'db_column_name')  // custom column name
  late String myField;

  @StanzaField(unique: true)    // UNIQUE constraint (schema management)
  late String email;

  @StanzaField(type: 'jsonb')   // override PG type (schema management)
  late String metadata;

  @StanzaField(defaultValue: 'NOW()')  // SQL default (schema management)
  late DateTime createdAt;

  @StanzaField(ignore: true)     // skip in generated code
  late String transient;

  @BelongsTo(Owner, onDelete: 'CASCADE')  // FK with referential action
  late int ownerId;

  static final $table = _$MyEntityTable();
}
```

### Full-Text Search & Trigram Similarity

```dart
// Full-text search WHERE (parameterized)
q.where(t.body).fullTextMatches('cats dogs');
q.where(t.body).fullTextMatches('"exact" -excluded', queryType: FtsQueryType.websearch);
q.where(t.body).fullTextMatches('fat cats', queryType: FtsQueryType.phrase);
q.where(t.body).fullTextMatches('gatos', config: FtsConfig.spanish);

// Trigram similarity WHERE (requires pg_trgm extension)
q.where(t.name).isSimilarTo('jonh');       // field % @param
q.where(t.name).isWordSimilarTo('cat');    // @param %> field

// Ranking and headlines (SELECT + ORDER BY)
q.selectRank(t.body, 'query');             // ts_rank() in SELECT, ORDER BY DESC
q.selectHeadline(t.body, 'query',          // ts_headline() in SELECT
    options: 'StartSel=<b>, StopSel=</b>');
q.selectSimilarity(t.name, 'jonh');        // similarity() in SELECT, ORDER BY DESC
q.orderByDistance(t.name, 'jonh');          // field <-> @param ASC (GiST-friendly)
```

### Schema Management

```bash
# Create bin/migrate.dart in your project, then:
dart run bin/migrate.dart status     # applied vs pending
dart run bin/migrate.dart diff       # code vs database
dart run bin/migrate.dart generate   # write .sql file
dart run bin/migrate.dart apply      # apply pending
dart run bin/migrate.dart apply --dry-run
```

```dart
// bin/migrate.dart (minimal script)
import 'dart:io';
import 'package:stanza/schema.dart';
import 'package:my_app/models.dart';

void main(List<String> args) => StanzaCli.run(
  args,
  databaseUrl: Platform.environment['DATABASE_URL']!,
  tables: [Owner.$table, Animal.$table],
);
```

```dart
// Or use the API directly:
final manager = SchemaManager(stanza,
  tables: [Owner.$table, Animal.$table],
  migrationsDir: 'migrations',
);
final ops = await manager.diff();       // List<SchemaDiffOp>
final path = await manager.generate();  // writes .sql file
final applied = await manager.apply();  // applies pending
```

**Barrel exports**: `package:stanza/stanza.dart` (query builder + schema types for codegen), `package:stanza/schema.dart` (full schema management), `package:stanza/annotations.dart` (annotations only)

## Integration Testing

- Uses Neon PostgreSQL via `DATABASE_URL` environment variable
- `.env` file is gitignored; see `.env.example` for format
- `Stanza.url()` auto-strips unsupported connection params (e.g., Neon's `channel_binding`)
