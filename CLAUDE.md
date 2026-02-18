# Stanza - Dart PostgreSQL Query Builder

Type-safe PostgreSQL query builder with code generation. Fluent API for SELECT, INSERT, UPDATE, DELETE with parameterized queries, JOINs, RETURNING, and typed result mapping.

## Project Structure

- `stanza/` - Runtime library (query builder, connection management, result types)
- `stanza_builder/` - Code generator (source_gen/build_runner, reads annotations → generates Table classes)
- `stanza/example/` - Example entity definitions with generated code
- `docs/assessment/stanza-modernized/ROADMAP.md` - Implementation roadmap (Phase 1 mostly complete)

## Branch Strategy

- `main` - Stable code
- `feature/modernization` - Active development branch

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

1. **stanza** (runtime) - Query classes, connection pool (postgres v3), result mapping
2. **stanza_builder** (codegen) - source_gen generator reads `@StanzaEntity`/`@StanzaField`/`@BelongsTo` annotations, generates typed `Table<T>` subclasses with `Field` accessors, `fromDb()`, `toDb()`, and JOIN helpers

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
| `stanza/lib/src/stanza.dart` | Stanza/StanzaSession classes (pool, execute, transactions) |
| `stanza/lib/src/annotations.dart` | @StanzaEntity, @StanzaField, @BelongsTo |
| `stanza/lib/src/table.dart` | Abstract Table<T> with fromDb/toDb |
| `stanza/lib/src/field.dart` | Field class with aggregates (sum, avg, count, min, max) |
| `stanza/lib/src/select/select_query.dart` | SelectQuery (joins, groupBy, orderBy, limit, offset) |
| `stanza/lib/src/insert/insert_query.dart` | InsertQuery (single field or entity) |
| `stanza/lib/src/update/update_query.dart` | UpdateQuery with SetValue (.string, .number, etc.) |
| `stanza/lib/src/delete/delete_query.dart` | DeleteQuery |
| `stanza/lib/src/shared/where_clause.dart` | WhereClause mixin (where/and/or) |
| `stanza/lib/src/shared/where_operations.dart` | WhereOperation (20+ comparison operators) |
| `stanza/lib/src/shared/returning_clause.dart` | ReturningClause mixin (returning/returningStar) |
| `stanza/lib/src/select/join_clause.dart` | JoinClause (inner, left, right, cross) |
| `stanza_builder/lib/src/stanza_entity_generator.dart` | Main code generator |

## Tests

- 10 test files in `stanza/stanza/test/`
- Unit tests cover all query types, WHERE operations, JOINs, RETURNING, field aggregates
- Integration tests in `integration_test.dart` require `DATABASE_URL` env var (Neon PostgreSQL); skipped gracefully when not set
- Test helpers in `test_helpers.dart` define mock `AnimalTable`, `OwnerTable`, `HabitatTable`

## API Quick Reference

### Connection

```dart
// From URL (Neon, Supabase, etc.)
final stanza = Stanza.url('postgresql://user:pass@host/db?sslmode=require');

// From credentials
final stanza = Stanza.tcp(PostgresCredentials('host', 5432, 'db', 'user', 'pass'));

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
  @StanzaField(readOnly: true)   // auto-generated columns (id, timestamps)
  late int id;

  @StanzaField(name: 'db_column_name')  // custom column name
  late String myField;

  @StanzaField(ignore: true)     // skip in generated code
  late String transient;

  @BelongsTo(Owner)              // foreign key → generates typed JOIN helpers
  late int ownerId;

  static final $table = _$MyEntityTable();
}
```

## Integration Testing

- Uses Neon PostgreSQL via `DATABASE_URL` environment variable
- `.env` file is gitignored; see `.env.example` for format
- `Stanza.url()` auto-strips unsupported connection params (e.g., Neon's `channel_binding`)
