# Stanza — Consumer Guide

Complete API reference for building applications with Stanza v2.

## Setup

```yaml
dependencies:
  stanza:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza
      ref: v2

dev_dependencies:
  build_runner: ^2.4.0
  stanza_builder:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza_builder
      ref: v2
```

## Quick Start

```dart
import 'package:stanza/stanza.dart';

part 'user.g.dart';

@Entity()
class User {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Field(length: 100, unique: true)
  final String email;

  final String name;

  @Field(defaultValue: 'now()')
  final DateTime createdAt;

  const User({required this.id, required this.email, required this.name, required this.createdAt});
}
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

```dart
final users = $UserTable();

// Query
final results = SelectQuery(users)
    .where((t) => t.email.like('%@example.com'))
    .orderBy((t) => t.createdAt.desc())
    .limit(10);

// Inspect SQL
final (:sql, :parameters) = results.build();
```

---

## Annotations

Import: `import 'package:stanza/annotations.dart';` (or `package:stanza/stanza.dart`)

### @Entity

Marks a class as a database entity.

```dart
const Entity({String? name})
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `name` | `String?` | `null` | Override table name. Default: pluralized snake_case of class name (`User` → `users`) |

### @PrimaryKey

Marks a field as the primary key.

```dart
const PrimaryKey({bool autoIncrement = true})
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `autoIncrement` | `bool` | `true` | Use SERIAL type for auto-incrementing IDs |

### @Field

Configures a field's database column.

```dart
const Field({String? name, int? length, bool unique = false, String? defaultValue, String? type, bool ignore = false})
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `name` | `String?` | `null` | Override column name. Default: snake_case of field name |
| `length` | `int?` | `null` | VARCHAR length: `@Field(length: 100)` → `varchar(100)` |
| `unique` | `bool` | `false` | Add UNIQUE constraint |
| `defaultValue` | `String?` | `null` | SQL DEFAULT expression: `'now()'`, `'true'` |
| `type` | `String?` | `null` | Override PostgreSQL type: `'jsonb'`, `'uuid'` |
| `ignore` | `bool` | `false` | Skip field in generated code |

### @References

Declares a foreign key relationship.

```dart
const References(Type entity, {String? column, String? onDelete})
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `entity` | `Type` | required | The referenced entity class |
| `column` | `String?` | `'id'` | Column on referenced table |
| `onDelete` | `String?` | `null` | Referential action: `'CASCADE'`, `'SET NULL'`, `'RESTRICT'` |

### @Database

Marks a class as the database entry point (for future use with generated `$AppDatabase`).

```dart
const Database({required List<Type> entities})
```

### Type Inference

| Dart Type | PostgreSQL Type |
|-----------|----------------|
| `int` | `integer` |
| `int` + `@PrimaryKey()` | `serial` |
| `String` | `text` |
| `String` + `@Field(length: n)` | `varchar(n)` |
| `bool` | `boolean` |
| `double` | `double precision` |
| `DateTime` | `timestamptz` |

---

## Generated Code

For each `@Entity` class, the code generator produces:

### Table Descriptor: `$EntityTable`

```dart
class $UserTable extends TableDescriptor<User> {
  String get tableName => 'users';

  final id = const IntColumn('id', 'users');
  final email = const StringColumn('email', 'users');
  final name = const StringColumn('name', 'users');
  final createdAt = const DateTimeColumn('created_at', 'users');

  List<Column> get columns => [id, email, name, createdAt];
  Column get primaryKey => id;

  User fromRow(Map<String, dynamic> row) => User(
    id: row['id'] as int,
    email: row['email'] as String,
    name: row['name'] as String,
    createdAt: row['created_at'] as DateTime,
  );

  SchemaTable get $schema => SchemaTable(...);  // full schema metadata
}
```

### Insert Companion: `EntityInsert`

Excludes auto-increment PK. Fields with `defaultValue` are optional.

```dart
class UserInsert {
  final String email;
  final String name;
  final DateTime? createdAt;  // optional — has DB default

  const UserInsert({required this.email, required this.name, this.createdAt});

  Map<String, dynamic> toRow() => {
    'email': email,
    'name': name,
    if (createdAt != null) 'created_at': createdAt,
  };
}
```

### Update Companion: `EntityUpdate`

All writable fields optional. Only non-null fields are included in the SET clause.

```dart
class UserUpdate {
  final String? email;
  final String? name;
  final DateTime? createdAt;

  const UserUpdate({this.email, this.name, this.createdAt});

  Map<String, dynamic> toRow() => {
    if (email != null) 'email': email,
    if (name != null) 'name': name,
    if (createdAt != null) 'created_at': createdAt,
  };
}
```

### copyWith Extension

```dart
extension UserCopyWith on User {
  User copyWith({int? id, String? email, String? name, DateTime? createdAt}) =>
    User(id: id ?? this.id, email: email ?? this.email, name: name ?? this.name, createdAt: createdAt ?? this.createdAt);
}
```

---

## Columns

All column types extend `Column<T>` and provide type-safe operations.

| Class | Dart Type | Created By |
|-------|-----------|------------|
| `IntColumn` | `int` | Generated for `int` fields |
| `DoubleColumn` | `double` | Generated for `double` fields |
| `StringColumn` | `String` | Generated for `String` fields |
| `BoolColumn` | `bool` | Generated for `bool` fields |
| `DateTimeColumn` | `DateTime` | Generated for `DateTime` fields |

### Universal Operations (all column types)

```dart
Expression equals(T value)           // column = @value
Expression notEquals(T value)        // column != @value
Expression isNull()                  // column IS NULL
Expression isNotNull()               // column IS NOT NULL
Expression isIn(List<T> values)      // column IN (@v0, @v1, ...)
Expression notIn(List<T> values)     // column NOT IN (@v0, @v1, ...)
Expression equalsColumn(Column<T> other)  // column = other_column (for JOINs)
Expression isInQuery(Query subquery)      // column IN (SELECT ...)
Expression notInQuery(Query subquery)     // column NOT IN (SELECT ...)
OrderExpression asc()                // column ASC
OrderExpression desc()               // column DESC
AggregateExpression count()          // COUNT(column)
AggregateExpression min()            // MIN(column)
AggregateExpression max()            // MAX(column)
```

### IntColumn

```dart
Expression greaterThan(int value)           // column > @value
Expression greaterThanOrEqual(int value)    // column >= @value
Expression lessThan(int value)              // column < @value
Expression lessThanOrEqual(int value)       // column <= @value
Expression between(int low, int high)       // column BETWEEN @low AND @high
AggregateExpression sum()                   // SUM(column)
AggregateExpression avg()                   // AVG(column)
```

### DoubleColumn

Same numeric operations as `IntColumn` but typed for `double`. Also has `sum()` and `avg()`.

### StringColumn

```dart
Expression like(String pattern)      // column LIKE @pattern (case-sensitive)
Expression ilike(String pattern)     // column ILIKE @pattern (case-insensitive)
Expression startsWith(String prefix) // column LIKE '@prefix%'
Expression endsWith(String suffix)   // column LIKE '%@suffix'
Expression contains(String sub)      // column LIKE '%@sub%'

// Full-text search
Expression fullTextMatches(String query, {
  FtsConfig config = FtsConfig.english,
  FtsQueryType queryType = FtsQueryType.plain,
})

// Trigram similarity (requires pg_trgm extension)
Expression isSimilarTo(String text)      // column % @text
Expression isWordSimilarTo(String text)  // @text %> column
```

### BoolColumn

```dart
Expression isTrue()    // column = true
Expression isFalse()   // column = false
```

### DateTimeColumn

```dart
Expression before(DateTime value)       // column < @value
Expression after(DateTime value)        // column > @value
Expression onOrBefore(DateTime value)   // column <= @value
Expression onOrAfter(DateTime value)    // column >= @value
Expression between(DateTime start, DateTime end)  // column BETWEEN @start AND @end
```

---

## Expressions

Expressions compose with `&` (AND) and `|` (OR):

```dart
// Simple
query.where((t) => t.email.equals('a@b.com'))

// Compound AND
query.where((t) => t.name.equals('Kirk') & t.email.like('%@example.com'))

// Compound OR
query.where((t) => t.name.equals('Kirk') | t.name.equals('Spock'))

// Mixed (parentheses are automatic)
query.where((t) => t.active.isTrue() & (t.role.equals('admin') | t.role.equals('mod')))
```

Multiple `.where()` calls are ANDed together:

```dart
query.where((t) => t.name.equals('Kirk'))
     .where((t) => t.email.isNotNull())
// WHERE users.name = @p0 AND users.email IS NOT NULL
```

### Raw Expressions

```dart
query.where((_) => Raw("users.data->>'key' = :val", paramValues: {'val': 'x'}))
```

---

## SELECT Queries

```dart
SelectQuery<T, D extends TableDescriptor<T>>(D table)
```

### Methods

```dart
SelectQuery<T, D> where(Expression Function(D t) predicate)
SelectQuery<T, D> orderBy(OrderExpression Function(D t) order)
SelectQuery<T, D> limit(int n)
SelectQuery<T, D> offset(int n)
SelectQuery<T, D> distinct()
SelectQuery<T, D> selectOnly(List<Column> Function(D t) columns)
SelectQuery<T, D> selectExpression(AggregateExpression agg)
SelectQuery<T, D> groupBy(List<Column> Function(D t) columns)
SelectQuery<T, D> having(Expression Function(D t) predicate)
SelectQuery<T, D> innerJoin<J, JD>(JD joinTable, Expression Function(D t, JD j) on)
SelectQuery<T, D> leftJoin<J, JD>(JD joinTable, Expression Function(D t, JD j) on)
SelectQuery<T, D> rightJoin<J, JD>(JD joinTable, Expression Function(D t, JD j) on)
```

### Examples

```dart
final users = $UserTable();

// Basic SELECT
SelectQuery(users)
    .where((t) => t.email.like('%@example.com'))
    .orderBy((t) => t.createdAt.desc())
    .limit(10)
    .offset(20);

// SELECT specific columns
SelectQuery(users)
    .selectOnly((t) => [t.id, t.email]);

// SELECT DISTINCT
SelectQuery(users).distinct();
```

---

## INSERT Queries

```dart
InsertQuery<T, D extends TableDescriptor<T>>(D table)
```

### Methods

```dart
InsertQuery<T, D> values(Map<String, dynamic> row)
InsertQuery<T, D> valuesList(List<Map<String, dynamic>> rows)
InsertQuery<T, D> returning()
InsertQuery<T, D> onConflict({required List<Column> target, required Map<String, dynamic> doUpdate})
InsertQuery<T, D> onConflictDoNothing({required List<Column> target})
```

### Examples

```dart
final users = $UserTable();

// Single insert
InsertQuery(users)
    .values(UserInsert(email: 'a@b.com', name: 'Kirk').toRow())
    .returning();

// Batch insert
InsertQuery(users)
    .valuesList([
      UserInsert(email: 'a@b.com', name: 'Kirk').toRow(),
      UserInsert(email: 'c@d.com', name: 'Spock').toRow(),
    ])
    .returning();

// Upsert (ON CONFLICT DO UPDATE)
InsertQuery(users)
    .values(UserInsert(email: 'a@b.com', name: 'Kirk').toRow())
    .onConflict(
      target: [users.email],
      doUpdate: UserUpdate(name: 'Kirk Updated').toRow(),
    )
    .returning();

// ON CONFLICT DO NOTHING
InsertQuery(users)
    .values(UserInsert(email: 'a@b.com', name: 'Kirk').toRow())
    .onConflictDoNothing(target: [users.email]);
```

---

## UPDATE Queries

```dart
UpdateQuery<T, D extends TableDescriptor<T>>(D table, Map<String, dynamic> values)
```

### Methods

```dart
UpdateQuery<T, D> where(Expression Function(D t) predicate)
UpdateQuery<T, D> returning()
UpdateQuery<T, D> allowUnsafe()   // required for UPDATE without WHERE
```

### Examples

```dart
final users = $UserTable();

// Update with WHERE
UpdateQuery(users, UserUpdate(name: 'Spock').toRow())
    .where((t) => t.id.equals(1));

// Update with RETURNING
UpdateQuery(users, UserUpdate(email: 'new@b.com').toRow())
    .where((t) => t.id.equals(1))
    .returning();

// Update all rows (requires allowUnsafe)
UpdateQuery(users, UserUpdate(name: 'Reset').toRow())
    .allowUnsafe();
```

**Safety:** UPDATE without `.where()` throws `StanzaException` unless `.allowUnsafe()` is called.

---

## DELETE Queries

```dart
DeleteQuery<T, D extends TableDescriptor<T>>(D table)
```

### Methods

```dart
DeleteQuery<T, D> where(Expression Function(D t) predicate)
DeleteQuery<T, D> returning()
DeleteQuery<T, D> allowUnsafe()   // required for DELETE without WHERE
```

### Examples

```dart
final users = $UserTable();

// Delete with WHERE
DeleteQuery(users)
    .where((t) => t.id.equals(1));

// Delete with RETURNING
DeleteQuery(users)
    .where((t) => t.email.equals('old@b.com'))
    .returning();
```

**Safety:** DELETE without `.where()` throws `StanzaException` unless `.allowUnsafe()` is called.

---

## JOINs

```dart
final users = $UserTable();
final posts = $PostTable();

// INNER JOIN
SelectQuery(posts)
    .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id));
// SELECT posts.* FROM posts INNER JOIN users ON posts.author_id = users.id

// LEFT JOIN
SelectQuery(posts)
    .leftJoin(users, (p, u) => p.authorId.equalsColumn(u.id));

// RIGHT JOIN
SelectQuery(posts)
    .rightJoin(users, (p, u) => p.authorId.equalsColumn(u.id));
```

---

## Aggregates, GROUP BY, HAVING

### AggregateExpression

Produced by column aggregate methods. Not an `Expression` — use `.as()` for SELECT and comparison methods for HAVING.

```dart
AggregateExpression count()   // on all columns
AggregateExpression min()     // on all columns
AggregateExpression max()     // on all columns
AggregateExpression sum()     // on IntColumn, DoubleColumn only
AggregateExpression avg()     // on IntColumn, DoubleColumn only
```

```dart
AggregateExpression as(String alias)     // alias for SELECT: COUNT(col) AS alias
String toSql()                            // COUNT(col)
String toSelectSql()                      // COUNT(col) AS alias (or COUNT(col) if no alias)
```

### CountAll

```dart
const CountAll({String? alias})    // COUNT(*)
```

### HAVING Comparisons

`AggregateExpression` provides comparison methods that return `Expression` for use in `.having()`:

```dart
Expression greaterThan(num value)
Expression greaterThanOrEqual(num value)
Expression lessThan(num value)
Expression lessThanOrEqual(num value)
Expression equals(num value)
Expression notEquals(num value)
Expression between(num low, num high)
```

### Examples

```dart
final posts = $PostTable();

// COUNT with GROUP BY
SelectQuery(posts)
    .selectOnly((t) => [t.authorId])
    .selectExpression(const CountAll(alias: 'count'))
    .groupBy((t) => [t.authorId]);
// SELECT posts.author_id, COUNT(*) AS count FROM posts GROUP BY posts.author_id

// HAVING
SelectQuery(posts)
    .selectOnly((t) => [t.authorId])
    .selectExpression(posts.id.count().as('post_count'))
    .groupBy((t) => [t.authorId])
    .having((t) => t.id.count().greaterThan(5));
// ... GROUP BY posts.author_id HAVING COUNT(posts.id) > @p0

// SUM and AVG
SelectQuery(posts)
    .selectOnly((t) => [t.authorId])
    .selectExpression(posts.authorId.sum().as('total'))
    .selectExpression(posts.authorId.avg().as('average'))
    .groupBy((t) => [t.authorId]);
```

---

## Full-Text Search

Requires no extensions for basic FTS. Trigram operations require `pg_trgm`.

### FtsConfig

```dart
enum FtsConfig {
  simple, english, spanish, french, german, italian, portuguese,
  russian, swedish, turkish, dutch, danish, finnish, hungarian,
  norwegian, romanian
}
```

### FtsQueryType

| Value | PostgreSQL Function | Behavior |
|-------|-------------------|----------|
| `plain` | `plainto_tsquery` | Splits on whitespace, ANDs terms |
| `websearch` | `websearch_to_tsquery` | Google-like: `"phrase" -exclude OR term` |
| `phrase` | `phraseto_tsquery` | Proximity matching (terms in order) |

### WHERE — Match Documents

```dart
// Default: plain text, English
query.where((t) => t.body.fullTextMatches('database optimization'));

// Websearch syntax
query.where((t) => t.body.fullTextMatches('"exact phrase" -exclude', queryType: FtsQueryType.websearch));

// Phrase search
query.where((t) => t.body.fullTextMatches('quick brown fox', queryType: FtsQueryType.phrase));

// Non-English
query.where((t) => t.body.fullTextMatches('base de datos', config: FtsConfig.spanish));
```

### SELECT — Ranking and Highlights

```dart
SelectQuery<T, D> selectRank(
  StringColumn Function(D t) column,
  String query, {
  String alias = 'rank',
  FtsConfig config = FtsConfig.english,
  FtsQueryType queryType = FtsQueryType.plain,
  bool orderByRank = true,        // adds ORDER BY ts_rank(...) DESC
})

SelectQuery<T, D> selectHeadline(
  StringColumn Function(D t) column,
  String query, {
  String alias = 'headline',
  FtsConfig config = FtsConfig.english,
  FtsQueryType queryType = FtsQueryType.plain,
  String? options,                 // PostgreSQL headline options
})
```

```dart
// Rank + headline
SelectQuery(posts)
    .where((t) => t.body.fullTextMatches('optimization'))
    .selectRank((t) => t.body, 'optimization')
    .selectHeadline((t) => t.body, 'optimization',
        options: 'StartSel=<b>, StopSel=</b>');
```

---

## Trigram Similarity

Requires `CREATE EXTENSION IF NOT EXISTS pg_trgm;`.

### WHERE — Fuzzy Match

```dart
// Similarity (% operator) — finds "john" when you type "jonh"
query.where((t) => t.name.isSimilarTo('jonh'));

// Word similarity (%> operator) — better for short queries against long text
query.where((t) => t.description.isWordSimilarTo('cat'));
```

### SELECT — Similarity Score and Distance

```dart
SelectQuery<T, D> selectSimilarity(
  StringColumn Function(D t) column,
  String text, {
  String alias = 'similarity_score',
  bool orderBySimilarity = true,   // adds ORDER BY similarity(...) DESC
})

SelectQuery<T, D> orderByDistance(
  StringColumn Function(D t) column,
  String text,                     // adds ORDER BY column <-> @text (GiST-friendly)
)
```

```dart
// Similarity score with auto-ordering
SelectQuery(users)
    .where((t) => t.name.isSimilarTo('jonh'))
    .selectSimilarity((t) => t.name, 'jonh');

// GiST-index-friendly distance ordering
SelectQuery(users)
    .where((t) => t.name.isSimilarTo('jonh'))
    .orderByDistance((t) => t.name, 'jonh');
```

---

## Subqueries

```dart
// WHERE col IN (SELECT ...)
final activeUserIds = SelectQuery(users)
    .selectOnly((t) => [t.id])
    .where((t) => t.createdAt.after(DateTime(2025)));

SelectQuery(posts)
    .where((t) => t.authorId.isInQuery(activeUserIds));
// WHERE posts.author_id IN (SELECT users.id FROM users WHERE users.created_at > @p0)

// WHERE col NOT IN (SELECT ...)
SelectQuery(posts)
    .where((t) => t.authorId.notInQuery(bannedUserIds));
```

Parameters from the subquery merge correctly with the outer query's parameters.

---

## Connection

```dart
import 'package:stanza/stanza.dart';
```

### Stanza

```dart
// From PostgreSQL URL (recommended)
final db = Stanza.url(
  'postgresql://user:pass@host/dbname',
  maxConnections: 25,           // default: 25
  sslMode: SslMode.require,    // default: disable
  connectTimeout: Duration(seconds: 15),
  queryTimeout: Duration(seconds: 30),
  applicationName: 'my-app',
);

// From existing postgres Pool
final db = Stanza.pool(existingPool);
```

Pools are cached — same URL returns same instance.

### Execute Queries

```dart
// Typed query execution
Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(Query<T, D> query)

// Raw SQL
Future<QueryResult<Never>> rawExecute(String sql, {Map<String, dynamic>? parameters})

// Raw SQL with mapper
Future<List<R>> rawQuery<R>(String sql, {
  Map<String, dynamic>? parameters,
  required R Function(Map<String, dynamic> row) mapper,
})
```

```dart
// Execute a SELECT
final result = await db.execute(selectQuery);
final users = result.entities;        // List<User>
final first = result.firstOrNull;     // User?

// Raw SQL
await db.rawExecute('CREATE TABLE ...');

// Raw SQL with mapper
final counts = await db.rawQuery<({String name, int count})>(
  'SELECT name, count(*) as count FROM users GROUP BY name',
  mapper: (row) => (name: row['name'] as String, count: row['count'] as int),
);
```

### Transactions

```dart
await db.transaction((session) async {
  final user = await session.execute(insertUserQuery);
  await session.execute(insertPostQuery);
  // Auto-rollback on throw
});

// Multiple queries on single connection (no transaction)
await db.run((session) async {
  await session.execute(query1);
  await session.execute(query2);
});
```

`StanzaSession` has the same `execute`, `rawExecute`, and `rawQuery` methods as `Stanza`.

### Streaming

```dart
Stream<T> stream<T, D extends TableDescriptor<T>>(Query<T, D> query)
```

```dart
await for (final user in db.stream(selectQuery)) {
  print(user.name);
}
```

### Close

```dart
await db.close();
```

---

## QueryResult

```dart
class QueryResult<T> {
  final List<Map<String, dynamic>> rows;   // raw database rows
  final int affectedRows;                   // for INSERT/UPDATE/DELETE without RETURNING

  List<T> get entities;     // mapped entity instances
  T? get firstOrNull;       // first entity or null
  bool get isEmpty;
  bool get isNotEmpty;
  int get length;
}
```

---

## TableAccessor

High-level CRUD interface, typically created by a generated `$AppDatabase`.

```dart
class TableAccessor<T, D extends TableDescriptor<T>> {
  TableAccessor(D descriptor, Stanza db);

  SelectQuery<T, D> select();
  Future<T> insertRow(Map<String, dynamic> values);
  Future<List<T>> insertRows(List<Map<String, dynamic>> rows);
  Future<T?> findById(Object id);
  UpdateQuery<T, D> updateWith(Map<String, dynamic> values);
  DeleteQuery<T, D> delete();
  Future<T> upsertRow(Map<String, dynamic> values, {
    required List<Column> Function(D t) conflictTarget,
    required Map<String, dynamic> updateValues,
  });
}
```

```dart
final accessor = TableAccessor($UserTable(), db);

// SELECT
final query = accessor.select()
    .where((t) => t.email.like('%@example.com'));
final users = await query.run(db);

// INSERT
final user = await accessor.insertRow(
  UserInsert(email: 'a@b.com', name: 'Kirk').toRow(),
);

// FIND BY ID
final user = await accessor.findById(42);

// UPSERT
final user = await accessor.upsertRow(
  UserInsert(email: 'a@b.com', name: 'Kirk').toRow(),
  conflictTarget: (t) => [t.email],
  updateValues: UserUpdate(name: 'Kirk Updated').toRow(),
);
```

### Executable Extensions

```dart
// SelectQuery
Future<List<T>> run(Stanza db);

// UpdateQuery
Future<int> run(Stanza db);                  // affected rows
Future<List<T>> runReturning(Stanza db);     // updated entities

// DeleteQuery
Future<int> run(Stanza db);                  // affected rows
Future<List<T>> runReturning(Stanza db);     // deleted entities
```

---

## SQL Inspection

Every query can output its SQL and parameters without executing:

```dart
// Get SQL string (needs a ParameterCollector)
final params = ParameterCollector();
final sql = query.toSql(params);
print(sql);            // SELECT users.* FROM users WHERE users.email = @p0
print(params.values);  // {p0: 'a@b.com'}

// Convenience: get both at once
final (:sql, :parameters) = query.build();
```

---

## Exceptions

```dart
class StanzaException implements Exception {
  final String message;
  final Object? cause;    // underlying postgres exception, if any
}
```

Thrown when:
- UPDATE/DELETE without `.where()` (and no `.allowUnsafe()`)
- INSERT with empty values
- Database connection failures
- Query execution errors

---

## Schema Management

Import: `import 'package:stanza/schema.dart';`

### Migration CLI

Create a `bin/migrate.dart`:

```dart
import 'dart:io';
import 'package:stanza/schema.dart';
import 'package:my_app/models.dart';

void main(List<String> args) => StanzaCli.run(
  args,
  databaseUrl: Platform.environment['DATABASE_URL']!,
  tables: [$UserTable(), $PostTable()],
);
```

```bash
dart run bin/migrate.dart status     # show applied vs pending
dart run bin/migrate.dart diff       # show code vs database differences
dart run bin/migrate.dart generate   # write timestamped .sql migration file
dart run bin/migrate.dart apply      # apply all pending migrations
dart run bin/migrate.dart apply --dry-run  # preview without executing
```

### Programmatic API

```dart
final manager = SchemaManager(
  db,
  tables: [$UserTable(), $PostTable()],
  migrationsDir: 'migrations',
);

final ops = await manager.diff();         // List<SchemaDiffOp>
final path = await manager.generate();    // writes .sql file, returns path (null if up-to-date)
final applied = await manager.apply();    // applies pending, returns filenames
final statuses = await manager.status();  // List<MigrationStatus>
```

### SchemaDiffOp Types

| Type | SQL Output |
|------|-----------|
| `CreateTable` | `CREATE TABLE ... (columns, constraints)` |
| `AddColumn` | `ALTER TABLE t ADD COLUMN col type [NOT NULL] [DEFAULT ...]` |
| `AlterColumnType` | `ALTER TABLE t ALTER COLUMN col TYPE newtype` |
| `AlterColumnNullability` | `ALTER TABLE t ALTER COLUMN col SET/DROP NOT NULL` |
| `AlterColumnDefault` | `ALTER TABLE t ALTER COLUMN col SET/DROP DEFAULT` |
| `AddConstraint` | `ALTER TABLE t ADD CONSTRAINT name PK/UNIQUE/FK (...)` |
| `DropColumn` | Commented out: `-- SAFETY: ALTER TABLE t DROP COLUMN col` |
| `DropConstraint` | `ALTER TABLE t DROP CONSTRAINT name` |

### MigrationStatus

```dart
class MigrationStatus {
  final String filename;
  final bool applied;
  final DateTime? appliedAt;
}
```

### How It Works

1. `SchemaManager` reads `$schema` from each table descriptor and queries `information_schema` for the live database state
2. Tables are topologically sorted by FK dependencies so parent tables are created first
3. `SchemaDiff.diff()` computes operations per table
4. `MigrationFileWriter` renders operations to a timestamped `.sql` file wrapped in `BEGIN`/`COMMIT`
5. `MigrationRunner` applies pending files in filename order, recording each in `_stanza_migrations` with a SHA-256 checksum
6. Modified applied migrations are rejected (checksum mismatch)

---

## Complete Example

```dart
import 'package:stanza/stanza.dart';

part 'models.g.dart';

// --- Entity Definitions ---

@Entity()
class User {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Field(length: 100, unique: true)
  final String email;

  @Field(length: 50)
  final String name;

  @Field(defaultValue: 'now()')
  final DateTime createdAt;

  const User({required this.id, required this.email, required this.name, required this.createdAt});
}

@Entity()
class Post {
  @PrimaryKey(autoIncrement: true)
  final int id;

  final String title;
  final String body;

  @References(User, onDelete: 'CASCADE')
  final int authorId;

  @Field(defaultValue: 'now()')
  final DateTime createdAt;

  const Post({required this.id, required this.title, required this.body, required this.authorId, required this.createdAt});
}

// --- Usage ---

Future<void> main() async {
  final db = Stanza.url('postgresql://user:pass@host/dbname');
  final users = $UserTable();
  final posts = $PostTable();

  // INSERT
  final insertQuery = InsertQuery(users)
      .values(UserInsert(email: 'kirk@enterprise.com', name: 'Kirk').toRow())
      .returning();
  final result = await db.execute(insertQuery);
  final kirk = result.entities.first;

  // SELECT with WHERE + ORDER BY + LIMIT
  final selectQuery = SelectQuery(users)
      .where((t) => t.email.like('%@enterprise.com'))
      .orderBy((t) => t.createdAt.desc())
      .limit(10);
  final crew = await db.execute(selectQuery);

  // UPDATE with companion
  final updateQuery = UpdateQuery(users, UserUpdate(name: 'Captain Kirk').toRow())
      .where((t) => t.id.equals(kirk.id));
  await db.execute(updateQuery);

  // JOIN
  final joinQuery = SelectQuery(posts)
      .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
      .where((t) => t.createdAt.after(DateTime(2025)));

  // Aggregate: posts per author
  final statsQuery = SelectQuery(posts)
      .selectOnly((t) => [t.authorId])
      .selectExpression(posts.id.count().as('post_count'))
      .groupBy((t) => [t.authorId])
      .having((t) => t.id.count().greaterThan(3))
      .orderBy((t) => t.authorId.asc());

  // Full-text search
  final searchQuery = SelectQuery(posts)
      .where((t) => t.body.fullTextMatches('warp drive', queryType: FtsQueryType.websearch))
      .selectRank((t) => t.body, 'warp drive')
      .selectHeadline((t) => t.body, 'warp drive');

  // Subquery
  final activeIds = SelectQuery(users)
      .selectOnly((t) => [t.id])
      .where((t) => t.createdAt.after(DateTime(2025)));
  final recentPosts = SelectQuery(posts)
      .where((t) => t.authorId.isInQuery(activeIds));

  // Transaction
  await db.transaction((session) async {
    await session.execute(
      InsertQuery(users)
          .values(UserInsert(email: 'spock@enterprise.com', name: 'Spock').toRow())
          .returning(),
    );
    await session.execute(
      InsertQuery(posts)
          .values(PostInsert(title: 'Logic', body: 'Fascinating.', authorId: 1).toRow()),
    );
  });

  // DELETE
  final deleteQuery = DeleteQuery(posts)
      .where((t) => t.authorId.equals(kirk.id))
      .returning();

  await db.close();
}
```
