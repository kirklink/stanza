# Stanza — Contributor Guide

Type-safe, AI-first PostgreSQL ORM for Dart. Two packages: `stanza` (runtime) and `stanza_builder` (code generation).

- For consumer-facing API reference, see [docs/guide.md](docs/guide.md)

## Commands

```bash
# Run tests (from stanza/stanza/)
dart test --reporter github 2>/dev/null    # full pass/fail output
dart test --reporter github 2>/dev/null | tail -1  # summary only

# Analyze
dart analyze                               # from stanza/stanza/ or stanza/stanza_builder/

# Regenerate example code (from stanza/stanza/example/)
dart run build_runner build --delete-conflicting-outputs

# Run example tests (from stanza/stanza/example/)
dart test --reporter github 2>/dev/null
```

## Branch

- `v2` — Active development (clean break from v1, no backward compatibility)

## Package Structure

### stanza/stanza/ (runtime)

| File | Purpose |
|------|---------|
| `lib/stanza.dart` | Main barrel export — everything |
| `lib/schema.dart` | Schema-only barrel — for migration scripts |
| `lib/annotations.dart` | Annotation-only barrel — for entity files |
| `lib/src/annotations.dart` | `Entity`, `Field`, `PrimaryKey`, `References`, `Database` |
| `lib/src/column.dart` | `Column<T>` hierarchy: Int, String, Bool, Double, DateTime columns |
| `lib/src/expression.dart` | Sealed `Expression` tree (18 subtypes) + `AggregateExpression`, `CountAll` |
| `lib/src/fts.dart` | `FtsConfig`, `FtsQueryType` enums |
| `lib/src/order.dart` | `OrderExpression` (column + ASC/DESC) |
| `lib/src/parameter.dart` | `ParameterCollector` — assigns `@p0`, `@p1`, collects values |
| `lib/src/query.dart` | Abstract `Query<T, D>` base with `toSql()` and `build()` |
| `lib/src/select_query.dart` | `SelectQuery` — WHERE, ORDER BY, JOIN, GROUP BY, HAVING, FTS projections |
| `lib/src/insert_query.dart` | `InsertQuery` — values, valuesList, returning, onConflict |
| `lib/src/update_query.dart` | `UpdateQuery` — SET from map, WHERE, returning, safety check |
| `lib/src/delete_query.dart` | `DeleteQuery` — WHERE, returning, safety check |
| `lib/src/stanza.dart` | `Stanza` (pool manager), `StanzaSession` (single connection) |
| `lib/src/table.dart` | Abstract `TableDescriptor<T>` — base for generated table classes |
| `lib/src/table_accessor.dart` | `TableAccessor` — typed CRUD, plus Executable extensions |
| `lib/src/result.dart` | `QueryResult<T>` — rows, entities, affectedRows |
| `lib/src/exception.dart` | `StanzaException` |
| `lib/src/schema/column_type.dart` | Dart ↔ Postgres type mapping, equivalence (serial ≡ integer) |
| `lib/src/schema/schema_column.dart` | `SchemaColumn` — name, type, nullable, default, PK, serial, unique |
| `lib/src/schema/schema_constraint.dart` | `ConstraintKind` enum + `SchemaConstraint` |
| `lib/src/schema/schema_table.dart` | `SchemaTable` — columns + constraints + naming helpers |
| `lib/src/schema/schema_diff.dart` | Sealed `SchemaDiffOp` (8 subtypes) + `SchemaDiff.diff()` |
| `lib/src/schema/db_introspector.dart` | `DbIntrospector` — reads `information_schema` |
| `lib/src/schema/migration_file.dart` | `MigrationFileWriter` — generates timestamped .sql files |
| `lib/src/schema/migration_runner.dart` | `MigrationRunner` — applies migrations, SHA-256 checksums |
| `lib/src/schema/schema_manager.dart` | `SchemaManager` — orchestrates diff → generate → apply |
| `lib/src/schema/stanza_cli.dart` | `StanzaCli` — CLI: status, diff, generate, apply |

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

The `$schema` getter generates full `SchemaTable` metadata including `SchemaColumn` types, constraints (PK, unique, FK), and defaults — used by `SchemaManager` for migration diffing.

### Schema Diff Engine

`SchemaDiff.diff(expected, actual)` compares a single table pair and returns a `List<SchemaDiffOp>`:
- `actual == null` → `CreateTable`
- New columns → `AddColumn`
- Type changes → `AlterColumnType` (skips serial ≡ integer equivalence)
- Nullability changes → `AlterColumnNullability`
- Default changes → `AlterColumnDefault` (skips serial columns entirely)
- Removed columns → `DropColumn` (commented out with `-- SAFETY:`)
- Constraint additions/removals → `AddConstraint`/`DropConstraint`

### Migration Pipeline

1. `SchemaManager` reads `$schema` from each `TableDescriptor`, topologically sorts by FK dependencies (Kahn's algorithm), introspects live database via `information_schema`
2. `SchemaDiff.diff()` produces operations per table
3. `MigrationFileWriter.generate()` renders operations to timestamped SQL wrapped in `BEGIN`/`COMMIT`
4. `MigrationRunner.apply()` executes pending files in filename order, records each in `_stanza_migrations` tracking table with SHA-256 checksum; rejects modified applied migrations

### Safety Constraints

- UPDATE/DELETE without `.where()` throw `StanzaException` at `toSql()` time unless `.allowUnsafe()` is called
- All user values go through `ParameterCollector` — never interpolated into SQL strings
- `DropColumn` DDL is commented out by default — must be manually uncommented
- Applied migrations are checksum-verified to prevent silent modification

## Testing

- **229 total:** 209 core tests in `stanza/stanza/test/` + 20 example tests
- Tests are pure Dart, no IO — construct columns/queries and assert SQL output
- Schema tests: `column_type_test.dart` (22), `schema_diff_test.dart` (28), `migration_file_test.dart` (7)
- Integration tests (live Postgres) skip gracefully without `DATABASE_URL`
- Use `--reporter github 2>/dev/null` to avoid ANSI output overflow

## Current Status

v2 rewrite complete (Phases 0-6). All features implemented and tested. Zero analysis issues.
