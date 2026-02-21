# Stanza — Contributor Guide

Type-safe, AI-first database-agnostic ORM for Dart. Four packages: `stanza` (core runtime), `stanza_postgres` (PostgreSQL adapter), `stanza_sqlite` (SQLite adapter), and `stanza_builder` (code generation).

- For consumer-facing API reference, see [docs/guide.md](docs/guide.md)

## Commands

```bash
# Run tests (from stanza/stanza/, stanza_sqlite/, or stanza/example/)
dart test --reporter github 2>/dev/null    # full pass/fail output
dart test --reporter github 2>/dev/null | tail -1  # summary only

# Analyze
dart analyze                               # from stanza/stanza/, stanza_postgres/, stanza_sqlite/, or stanza_builder/

# Regenerate example code (from stanza/stanza/example/)
dart run build_runner build --delete-conflicting-outputs

# Run example tests (from stanza/stanza/example/)
dart test --reporter github 2>/dev/null
```

## Branch

- `dev` — Active development

## Package Structure

### stanza/stanza/ (core runtime — database-agnostic)

| File | Purpose |
|------|---------|
| `lib/stanza.dart` | Main barrel export — everything |
| `lib/schema.dart` | Schema-only barrel — for migration scripts |
| `lib/annotations.dart` | Annotation-only barrel — for entity files |
| `lib/src/annotations.dart` | `Entity`, `Field`, `PrimaryKey`, `References`, `Database` |
| `lib/src/column.dart` | `Column<T>` hierarchy: Int, String, Bool, Double, DateTime columns |
| `lib/src/database.dart` | `DatabaseAdapter`, `SessionAdapter` abstract interfaces, `AdapterSessionBlock` typedef |
| `lib/src/expression.dart` | Sealed `Expression` tree (18 subtypes) + `AggregateExpression`, `CountAll` |
| `lib/src/fts.dart` | `FtsConfig`, `FtsQueryType` enums |
| `lib/src/order.dart` | `OrderExpression` (column + ASC/DESC) |
| `lib/src/parameter.dart` | `ParameterCollector` — assigns parameterized placeholders, configurable prefix (`@` for Postgres, `:` for SQLite) |
| `lib/src/query.dart` | Abstract `Query<T, D>` base with `toSql()` and `build()` |
| `lib/src/select_query.dart` | `SelectQuery` — WHERE, ORDER BY, JOIN, GROUP BY, HAVING, FTS projections |
| `lib/src/insert_query.dart` | `InsertQuery` — values, valuesList, returning, onConflict |
| `lib/src/update_query.dart` | `UpdateQuery` — SET from map, WHERE, returning, safety check |
| `lib/src/delete_query.dart` | `DeleteQuery` — WHERE, returning, safety check |
| `lib/src/table.dart` | Abstract `TableDescriptor<T>` — base for generated table classes |
| `lib/src/table_accessor.dart` | `TableAccessor` — typed CRUD, plus Executable extensions (accepts `DatabaseAdapter`) |
| `lib/src/result.dart` | `QueryResult<T>` — rows, entities, affectedRows |
| `lib/src/exception.dart` | `StanzaException` |
| `lib/src/schema/column_type.dart` | Dart ↔ SQL type mapping, equivalence (serial ≡ integer) |
| `lib/src/schema/schema_column.dart` | `SchemaColumn` — name, type, dartTypeName, nullable, default, PK, serial, unique |
| `lib/src/schema/schema_constraint.dart` | `ConstraintKind` enum + `SchemaConstraint` |
| `lib/src/schema/schema_table.dart` | `SchemaTable` — columns + constraints + naming helpers |
| `lib/src/schema/schema_diff.dart` | Sealed `SchemaDiffOp` (8 subtypes) + `SchemaDiff.diff()` |
| `lib/src/schema/migration_file.dart` | `MigrationFileWriter` — generates timestamped .sql files |

### stanza/stanza_postgres/ (PostgreSQL adapter)

| File | Purpose |
|------|---------|
| `lib/stanza_postgres.dart` | Barrel export — Stanza, schema, CLI |
| `lib/src/postgres_database.dart` | `Stanza` (pool manager, implements `DatabaseAdapter`), `StanzaSession` (implements `SessionAdapter`) |
| `lib/src/schema/pg_introspector.dart` | `PgIntrospector` — reads `information_schema` |
| `lib/src/schema/pg_migration_runner.dart` | `PgMigrationRunner` — applies migrations, SHA-256 checksums, tracking table |
| `lib/src/schema/pg_schema_manager.dart` | `PgSchemaManager` — orchestrates diff → generate → apply |
| `lib/src/schema/pg_cli.dart` | `PgCli` — CLI: status, diff, generate, apply |

### stanza/stanza_sqlite/ (SQLite adapter)

| File | Purpose |
|------|---------|
| `lib/stanza_sqlite.dart` | Barrel export — StanzaSqlite, schema, CLI |
| `lib/src/sqlite_database.dart` | `StanzaSqlite` (file/memory, implements `DatabaseAdapter`), `SqliteSession` (implements `SessionAdapter`) |
| `lib/src/schema/sqlite_ddl.dart` | `SqliteDdl` — SQLite-specific DDL generation from `SchemaDiffOp` |
| `lib/src/schema/sqlite_introspector.dart` | `SqliteIntrospector` — reads `PRAGMA table_info`, `foreign_key_list`, `index_list` |
| `lib/src/schema/sqlite_migration_runner.dart` | `SqliteMigrationRunner` — applies migrations, SHA-256 checksums, tracking table |
| `lib/src/schema/sqlite_schema_manager.dart` | `SqliteSchemaManager` — orchestrates diff → generate → apply |
| `lib/src/schema/sqlite_cli.dart` | `SqliteCli` — CLI: status, diff, generate, apply |

### stanza/stanza_builder/ (code generation)

| File | Purpose |
|------|---------|
| `lib/builder.dart` | `stanzaBuilder()` entry point — `SharedPartBuilder` |
| `lib/src/entity_generator.dart` | `EntityGenerator` — generates `$Table`, companions, copyWith, `$schema` |
| `lib/src/type_mapping.dart` | `columnClassForDartType()`, `postgresTypeForDartType()`, `serialTypeForDartType()` |
| `build.yaml` | Builder config: `stanza_entity`, `build_to: cache`, `combining_builder` |

### stanza/stanza/example/ (test harness)

| File | Purpose |
|------|---------|
| `lib/src/models.dart` | `User` and `Post` entities with annotations |
| `lib/src/models.g.dart` | Generated code: `$UserTable`, `$PostTable`, companions |
| `test/models_test.dart` | 20 tests against generated code |

## Architecture

### Database Adapter Pattern

The core package defines abstract interfaces that decouple query execution from any specific driver:

```dart
abstract class DatabaseAdapter {
  Future<QueryResult<T>> execute<T, D>(Query<T, D> query);
  Future<QueryResult<Never>> rawExecute(String sql, {Map<String, dynamic>? parameters});
  Future<T> run<T>(AdapterSessionBlock<T> block);
  Future<T> transaction<T>(AdapterSessionBlock<T> block);
  Future<List<R>> rawQuery<R>(String sql, {...});
  ParameterCollector createParameterCollector();
  Future<void> close();
}
```

`Stanza` in `stanza_postgres` implements `DatabaseAdapter` using the `postgres` v3 driver. `StanzaSqlite` in `stanza_sqlite` implements it using the `sqlite3` FFI driver.

`ParameterCollector` has a configurable `placeholderPrefix` — `@` for Postgres (`@p0`), `:` for SQLite (`:p0`). The values map keys stay unprefixed (`p0`); only the SQL placeholder changes.

### Two-Type-Parameter Pattern

All query builders use `<T, D extends TableDescriptor<T>>` — `T` is the entity type, `D` is the table descriptor. This enables typed callbacks:

```dart
SelectQuery<User, $UserTable>(users).where((t) => t.email.equals('x'));
//                                          ^ t is $UserTable, so t.email is StringColumn
```

Dart sometimes can't infer `T` from `D extends TableDescriptor<T>` alone. When constructing queries inside `TableAccessor`, explicit type params are required: `SelectQuery<T, D>(descriptor)`.

### Expression System

`Expression` is a sealed class with 18 subtypes. Column methods return `Expression` objects. `&` and `|` compose them into `And` and `Or` trees. `toSql(ParameterCollector)` renders to parameterized SQL.

`AggregateExpression` is **not** a sealed subtype — it's standalone. Its comparison methods (`greaterThan`, `equals`, etc.) produce `AggregateComparison`/`AggregateBetween` Expression subtypes for HAVING clauses.

### FTS Architecture

Full-text search uses two layers:
1. **Expression level:** `FullTextMatch`, `TrigramSimilar`, `TrigramWordSimilar` are sealed Expression subtypes — used in WHERE clauses via `StringColumn.fullTextMatches()`, etc.
2. **SelectQuery level:** `selectRank()`, `selectHeadline()`, `selectSimilarity()`, `orderByDistance()` use `_RawFragment` internally — SQL template strings with named placeholders that get resolved to `@pN` via `ParameterCollector`.

The `_RawFragment` approach avoids adding FTS-specific types to the Expression hierarchy for projections that aren't WHERE conditions.

### Subquery Parameters

`SubqueryIn`/`SubqueryNotIn` store a `String Function(ParameterCollector)` closure instead of a `Query` reference. The outer query's `ParameterCollector` is passed through, so subquery parameters merge correctly with outer parameters (`@p0` for outer, `@p1` for subquery, etc.).

### Code Generator

`EntityGenerator extends GeneratorForAnnotation<Entity>` processes annotated classes and emits:
1. `$EntityTable extends TableDescriptor<Entity>` — typed columns, `fromRow()`, `$schema`
2. `EntityInsert` — required fields minus auto-increment PK; optional fields with DB defaults
3. `EntityUpdate` — all writable fields optional; `toRow()` omits nulls
4. `EntityCopyWith` extension — `copyWith()` on the entity

Field naming: Dart camelCase → snake_case column names (via `recase` package). Table naming: class name → pluralized snake_case.

The `$schema` getter generates full `SchemaTable` metadata including `SchemaColumn` types (with `dartTypeName` for cross-dialect mapping), constraints (PK, unique, FK), and defaults — used by `PgSchemaManager` for migration diffing.

### Schema Diff Engine

`SchemaDiff.diff(expected, actual)` compares a single table pair and returns a `List<SchemaDiffOp>`:
- `actual == null` → `CreateTable`
- New columns → `AddColumn`
- Type changes → `AlterColumnType` (skips serial ≡ integer equivalence)
- Nullability changes → `AlterColumnNullability`
- Default changes → `AlterColumnDefault` (skips serial columns entirely)
- Removed columns → `DropColumn` (commented out with `-- SAFETY:`)
- Constraint additions/removals → `AddConstraint`/`DropConstraint`

### Migration Pipeline (PostgreSQL)

1. `PgSchemaManager` reads `$schema` from each `TableDescriptor`, topologically sorts by FK dependencies (Kahn's algorithm), introspects live database via `PgIntrospector` (queries `information_schema`)
2. `SchemaDiff.diff()` produces operations per table
3. `MigrationFileWriter.generate()` renders operations to timestamped SQL wrapped in `BEGIN`/`COMMIT`
4. `PgMigrationRunner.apply()` executes pending files in filename order, records each in `_stanza_migrations` tracking table with SHA-256 checksum; rejects modified applied migrations

### Migration Pipeline (SQLite)

1. Same as PostgreSQL pipeline (topological sort, `SchemaDiff.diff()`) but uses:
   - `SqliteIntrospector` — reads schema via `PRAGMA table_info`, `PRAGMA foreign_key_list`, `PRAGMA index_list`
   - `SqliteDdl.generateMigration()` — renders SQLite-specific DDL (`INTEGER PRIMARY KEY` instead of `SERIAL`, `datetime('now')` instead of `NOW()`, type mapping via `dartTypeName`)
   - `SqliteMigrationRunner` — same tracking table pattern but with SQLite-compatible DDL
2. SQLite limitations: only `CREATE TABLE` and `ADD COLUMN` fully supported. `ALTER COLUMN`, `ADD/DROP CONSTRAINT` rendered as TODO comments (requires table rebuild in SQLite).

### SQLite Type Conversion

`StanzaSqlite` handles type conversion between Dart and SQLite storage types:
- **On write:** `bool` → `int` (0/1), `DateTime` → `String` (ISO 8601 UTC)
- **On read:** Uses `$schema.columns[].dartTypeName` to reverse conversions before `fromRow()` — `int` → `bool`, `String` → `DateTime`

This ensures generated `fromRow()` code (which does `row['active'] as bool`) works identically across Postgres and SQLite.

### Safety Constraints

- UPDATE/DELETE without `.where()` throw `StanzaException` at `toSql()` time unless `.allowUnsafe()` is called
- All user values go through `ParameterCollector` — never interpolated into SQL strings
- `DropColumn` DDL is commented out by default — must be manually uncommented
- Applied migrations are checksum-verified to prevent silent modification

## Testing

- **296 total:** 209 core + 67 SQLite + 20 example tests
- Core tests are pure Dart, no IO — construct columns/queries and assert SQL output
- SQLite tests use in-memory databases (`StanzaSqlite.memory()`) — no file IO, fast
- Schema tests: `column_type_test.dart` (22), `schema_diff_test.dart` (28), `migration_file_test.dart` (7)
- SQLite tests: `sqlite_database_test.dart` (16), `sqlite_ddl_test.dart` (30), `sqlite_introspector_test.dart` (11), `sqlite_migration_runner_test.dart` (10)
- Postgres integration tests skip gracefully without `DATABASE_URL`
- SQLite requires `libsqlite3-dev` system package for FFI bindings
- Use `--reporter github 2>/dev/null` to avoid ANSI output overflow

## Current Status

v2 rewrite complete with multi-database adapter support. Core package is database-agnostic; PostgreSQL adapter in `stanza_postgres`; SQLite adapter in `stanza_sqlite`. Zero analysis issues across all packages.
