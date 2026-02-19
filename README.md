# stanza

A type-safe PostgreSQL query builder for Dart with code generation.

- [overview](#overview)
- [what it is](#what-it-is)
- [what it is not](#what-it-is-not)
- [setup](#setup)
- [how to use it](#how-to-use-it)
  - [annotate a class](#annotate-a-class)
  - [connect to the database](#connect-to-the-database)
  - [build and run queries](#build-and-run-queries)
  - [SELECT queries](#select-queries)
  - [INSERT queries](#insert-queries)
  - [UPDATE queries](#update-queries)
  - [DELETE queries](#delete-queries)
  - [WHERE clauses](#where-clauses)
  - [JOINs](#joins)
  - [RETURNING clause](#returning-clause)
  - [aggregates](#aggregates)
  - [transactions](#transactions)
  - [raw SQL](#raw-sql)
  - [print a query](#print-a-query)
  - [fork a query](#fork-a-query)

## overview

Stanza is a library for writing PostgreSQL statements in a type-safe, Dart-native syntax. It pairs a fluent query builder with code generation to give you typed table accessors, field references, and result mapping — without writing raw SQL.

## what it is

Stanza sits on top of the [postgres](https://pub.dev/packages/postgres) (v3) package for database connectivity with connection pooling and SSL/TLS support. The companion `stanza_builder` package uses `source_gen` and `build_runner` to generate typed `Table` classes from annotated Dart models, providing compile-time safety for query construction.

## what it is not

Stanza is not an ORM. It does not manage database schema (creating tables, migrations) or track object state. It gives you a type-safe query builder and leaves schema management, connection lifecycle, and application architecture to you.

## setup

Add stanza as a dependency and stanza_builder as a dev dependency:

```yaml
dependencies:
  stanza:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza
      ref: feature/modernization

dev_dependencies:
  build_runner: ^2.4.0
  stanza_builder:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza_builder
      ref: feature/modernization
```

## how to use it

### annotate a class

Create a model class that mirrors your database table and annotate it with stanza decorators:

```dart
import 'package:stanza/annotations.dart';
import 'package:stanza/stanza.dart';

part 'animal.g.dart';

@StanzaEntity(name: 'mammal', snakeCase: true)
class Animal {
  @StanzaField(readOnly: true)
  late int id;
  late String name;
  @StanzaField(name: 'number_of_legs')
  late int legs;
  late String color;
  late DateTime createdAt;

  @BelongsTo(Owner)
  late int ownerId;

  Animal();

  static final _$AnimalTable $table = _$AnimalTable();
}
```

**Annotation reference:**

| Annotation | Level | Purpose |
|---|---|---|
| `@StanzaEntity(name: 'mammal')` | Class | Map class to a different table name |
| `@StanzaEntity(snakeCase: true)` | Class | Auto-convert all field names to snake_case |
| `@StanzaEntity(readOnly: true)` | Class | Prevent writes for the entire entity |
| `@StanzaField(readOnly: true)` | Field | Exclude from writes (e.g., auto-increment IDs) |
| `@StanzaField(name: 'db_column')` | Field | Map field to a different column name |
| `@StanzaField(ignore: true)` | Field | Skip field entirely in generated code |
| `@BelongsTo(Owner)` | Field | Declare a foreign key relationship for typed JOINs |

Run code generation to produce the typed table class:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates a file with `_$AnimalTable` containing typed `Field` accessors for each property, plus `fromDb()` and `toDb()` mapping methods. For `@BelongsTo` fields, it also generates typed JOIN helpers and result extraction methods.

The `static final $table` accessor is the entry point for all query operations.

### connect to the database

```dart
import 'package:stanza/stanza.dart';

// From a connection URL (recommended for cloud providers like Neon, Supabase):
var stanza = Stanza.url('postgresql://user:pass@host.neon.tech/db?sslmode=require');

// From explicit credentials:
var creds = PostgresCredentials('localhost', 5432, 'mydb', 'user', 'password');
var stanza = Stanza.tcp(creds, maxConnections: 10);

// With full connection configuration:
var stanza = Stanza.tcp(creds,
  maxConnections: 25,
  sslMode: SslMode.require,          // disable, require, or verifyFull
  connectTimeout: Duration(seconds: 15),
  queryTimeout: Duration(seconds: 30),
  applicationName: 'my-app',         // visible in pg_stat_activity
);

// Unix socket:
var stanza = Stanza.unix(creds, maxConnections: 10);
```

`SslMode` is re-exported from `package:stanza/stanza.dart` — no need to import `package:postgres` directly.

Stanza caches connection pools internally — calling the same constructor with the same connection details reuses the existing pool.

### build and run queries

```dart
var table = Animal.$table;

var query = SelectQuery(table)
  ..selectStar()
  ..where(table.color).matches('orange')
  ..limit(10);

var result = await stanza.execute<Animal>(query);
for (var r in result.all) {
  print(r.value?.name);
}
```

Results are returned as `QueryResult<T>`:
- `result.all` — full list of `Result<T>` objects
- `result.first` — first result (or null)
- `result.entities` — list of typed entity values only
- `result.aggregates` — list of aggregate maps only
- `result.isEmpty` / `result.isNotEmpty` / `result.length`

Each `Result<T>` contains:
- `.value` — the typed entity (mapped via `fromDb()`)
- `.aggregate` — a `Map<String, dynamic>` of any extra columns (aggregates, aliased joins, etc.)

### SELECT queries

```dart
var q = SelectQuery(table)
  ..selectFields([table.id, table.name, table.color])
  ..where(table.legs).isGreaterThan(2)
  ..and(table.color).matches('brown')
  ..orderBy(table.name)
  ..orderBy(table.id, descending: true)
  ..offset(20)
  ..limit(10);
```

- `selectStar()` — select all fields
- `selectFields([...])` — select specific fields
- `distinct()` — `SELECT DISTINCT` to eliminate duplicate rows
- `groupBy([...])` — GROUP BY clause
- `having(field)` / `andHaving(field)` / `orHaving(field)` — HAVING clause (filter after GROUP BY, typically with aggregates)
- `orderBy(field, {descending: false})` — ORDER BY (can be called multiple times)
- `limit(n)` / `offset(n)` — pagination

### INSERT queries

```dart
// Insert an entire entity:
var animal = Animal()..name = 'Tiger'..legs = 4..color = 'orange';
var q = InsertQuery(table)..insertEntity<Animal>(animal);

// Or insert individual fields:
var q = InsertQuery(table)
  ..insert(table.name, 'Tiger')
  ..insert(table.legs, 4)
  ..insert(table.color, 'orange');

// Batch insert (multiple entities in one statement):
var q = InsertQuery(table)
  ..insertEntities<Animal>([tiger, eagle, snake]);
// Produces: INSERT INTO mammal (cols) VALUES (...), (...), (...)
```

Fields marked `readOnly` are automatically excluded from `insertEntity` and `insertEntities`.

### Upsert (ON CONFLICT)

```dart
// Insert or update on conflict:
var q = InsertQuery(table)
  ..insertEntity<Animal>(animal)
  ..onConflict(
    target: [table.name],  // conflict column(s) — must have a unique constraint
    doUpdate: (set) => set
      ..column(table.color).string('updated-orange')
      ..column(table.legs).integer(4),
  )
  ..returningStar();

// Insert or skip on conflict:
var q = InsertQuery(table)
  ..insertEntity<Animal>(animal)
  ..onConflictDoNothing(target: [table.name]);
```

The `doUpdate` callback receives a `ConflictSetBuilder` with the same typed setters as UPDATE queries (`.string()`, `.integer()`, `.number()`, etc.).

### UPDATE queries

```dart
var q = UpdateQuery(table)
  ..column(table.color).string('white')
  ..column(table.legs).integer(4)
  ..where(table.id).isEqualTo(1);
```

Typed setters prevent accidental type mismatches:
- `.string(String)`, `.number(num)`, `.integer(int)`, `.float(double)`
- `.boolean(bool)`, `.datetime(DateTime)`, `.any(dynamic)`

**Safety**: UPDATE queries require a WHERE clause. Stanza will throw an exception if you try to execute an UPDATE without one, unless you explicitly pass `overrideSafety: true`.

### DELETE queries

```dart
var q = DeleteQuery(table)
  ..where(table.id).isEqualTo(1);
```

**Safety**: Like UPDATE, DELETE queries require a WHERE clause unless `overrideSafety: true` is passed.

### WHERE clauses

WHERE conditions are available on SELECT, UPDATE, and DELETE queries:

```dart
q.where(table.field)   // first condition
q.and(table.field)     // AND
q.or(table.field)      // OR
```

Each returns a `WhereOperation` with these comparison methods:

| Method | Accepts | SQL |
|---|---|---|
| `.isEqualTo(n)` | `num` | `= n` |
| `.isGreaterThan(n)` | `num` | `> n` |
| `.isGreaterThanOrEqualTo(n)` | `num` | `>= n` |
| `.isLessThan(n)` | `num` | `< n` |
| `.isLessThanOrEqualTo(n)` | `num` | `<= n` |
| `.matches(s, {caseSensitive})` | `String` | `= s` or `ILIKE s` |
| `.startsWith(s, {caseSensitive})` | `String` | `LIKE 's%'` |
| `.endsWith(s, {caseSensitive})` | `String` | `LIKE '%s'` |
| `.contains(s, {caseSensitive})` | `String` | `LIKE '%s%'` |
| `.isTrue()` | — | `= TRUE` |
| `.isFalse()` | — | `= FALSE` |
| `.isIn(list)` | `List<Object>` | `IN (@v0, @v1, ...)` |
| `.isNotIn(list)` | `List<Object>` | `NOT IN (@v0, @v1, ...)` |
| `.isBetween(low, high)` | `Object, Object` | `BETWEEN @low AND @high` |
| `.isNull()` | — | `IS NULL` |
| `.isNotNull()` | — | `IS NOT NULL` |
| `.isBefore(dt)` | `DateTime` | `< dt` |
| `.isAfter(dt)` | `DateTime` | `> dt` |
| `.isOn(dt)` | `DateTime` | `= dt` |
| `.raw(sql)` | `String` | raw SQL condition |

**Note**: `.isEqualTo()` accepts `num` only. For string equality, use `.matches()` with `caseSensitive: true`.

**Note**: `.isIn()` and `.isNotIn()` throw `StanzaException` if passed an empty list.

Brackets can group conditions:

```dart
q.where(table.name).startsWith('t')
 .and(table.legs, openBracket: true).isLessThan(4)
 .or(table.legs, closeBracket: true).isGreaterThan(6);
// WHERE name LIKE 't%' AND (legs < 4 OR legs > 6)
```

### JOINs

Stanza supports INNER, LEFT, RIGHT, and CROSS joins.

**Using generated helpers** (from `@BelongsTo`):

```dart
var q = SelectQuery(Animal.$table)..selectStar();
Animal.$table.innerJoinOwner(q);  // adds aliased fields + JOIN clause
q.where(Owner.$table.name).matches('alice');

var result = await stanza.execute<Animal>(q);
for (var r in result.all) {
  var animal = r.value;
  var owner = Animal.$table.ownerFromRow(r.aggregate);
  print('${animal?.name} belongs to ${owner?.name}');
}
```

The generated `innerJoinOwner()` / `leftJoinOwner()` methods automatically add aliased SELECT fields and the JOIN clause. The `ownerFromRow()` method extracts a typed entity from the aliased columns, returning `null` for LEFT JOIN misses.

**Manual joins:**

```dart
var q = SelectQuery(Animal.$table)
  ..selectStar()
  ..innerJoin(Owner.$table).on(Animal.$table.ownerId, Owner.$table.id);
```

Available join methods: `innerJoin()`, `leftJoin()`, `rightJoin()`, `crossJoin()`.

### RETURNING clause

INSERT, UPDATE, and DELETE queries can return affected rows without a follow-up SELECT:

```dart
// Return all columns:
var q = InsertQuery(table)
  ..insertEntity<Animal>(animal)
  ..returningStar();

// Return specific columns:
var q = DeleteQuery(table)
  ..where(table.id).isEqualTo(1)
  ..returning([table.id, table.name]);
```

### aggregates

Fields can be wrapped in aggregate functions for SELECT queries:

```dart
var q = SelectQuery(table)
  ..selectFields([
    table.color,
    table.id.count().rename('animal_count'),
  ])
  ..groupBy([table.color]);

var result = await stanza.execute<Animal>(q);
for (var r in result.all) {
  print('${r.aggregate['animal_count']} ${r.value?.color} animals');
}
```

Available aggregates: `.count()`, `.sum()`, `.avg()`, `.min()`, `.max()`.

Use `.rename('alias')` to give the aggregate a custom name in the result map.

#### DISTINCT

```dart
var q = SelectQuery(table)
  ..distinct()
  ..selectFields([table.color]);
```

#### HAVING

Use `having()` to filter groups by aggregate values (goes after `groupBy()`):

```dart
var q = SelectQuery(table)
  ..selectFields([
    table.color,
    table.id.count().rename('animal_count'),
  ])
  ..groupBy([table.color])
  ..having(table.id..count()).isGreaterThan(2);
```

Chain with `andHaving()` / `orHaving()` for multiple conditions. `having()` accepts the same comparison methods as `where()` (`.isEqualTo()`, `.isGreaterThan()`, etc.).

### transactions

```dart
var result = await stanza.runTransaction<Animal>((session) async {
  await session.execute(insertQuery);
  return session.execute<Animal>(selectQuery);
});
```

If any statement throws, the transaction is automatically rolled back.

For multiple queries on the same connection without a transaction, use `stanza.run()`:

```dart
await stanza.run((session) async {
  await session.execute(insertQuery);
  return session.execute<Animal>(selectQuery);
});
```

### streaming results

For large result sets, `stream<T>()` uses postgres v3 prepared statements to deliver rows one at a time without buffering the entire result in memory:

```dart
await for (final row in stanza.stream<Animal>(selectQuery)) {
  print(row.value?.name);       // typed entity
  print(row.aggregate);          // raw column map
}
```

Each element is a `Result<T>` — the same type returned inside `QueryResult.all`. Streaming is also available on `StanzaSession` inside `run()` and `runTransaction()` blocks:

```dart
await stanza.run((session) async {
  await for (final row in session.stream<Animal>(selectQuery)) {
    process(row);
  }
});
```

### raw SQL

For DDL, migrations, or anything the query builder doesn't cover:

```dart
await stanza.rawExecute('CREATE TABLE IF NOT EXISTS animals (id SERIAL PRIMARY KEY, name TEXT)');

await stanza.rawExecute(
  'INSERT INTO animals (name) VALUES (@name)',
  parameters: {'name': 'Tiger'},
);
```

`rawExecute` is also available on `StanzaSession` inside `run()` and `runTransaction()` blocks.

### print a query

Any query can be printed with standard SQL formatting:

```dart
print(query.statement(pretty: true));
```

This outputs the SQL with line breaks between clauses for readability.

### fork a query

Queries can be partially built and then forked to create independent copies:

```dart
var base = SelectQuery(table)
  ..selectStar()
  ..where(table.legs).isGreaterThan(2);

for (var color in ['orange', 'brown', 'white']) {
  var q = base.fork()
    ..and(table.color).matches(color);
  var result = await stanza.execute<Animal>(q);
  print('$color: ${result.length} animals');
}
```

The forked query is a deep copy — modifying it does not affect the original.
