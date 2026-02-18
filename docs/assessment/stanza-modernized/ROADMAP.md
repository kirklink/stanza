# Stanza: Assessment & Implementation Plan

## Current State

Stanza has been modernized to Dart 3, null safety, and postgres v3. The core architecture is sound: annotation-based code generation produces typed table classes with field accessors, and a fluent query builder produces parameterized SQL. The connection layer uses postgres v3's built-in pool with session and transaction support.

What exists today:
- SELECT with fields, star, WHERE (and/or with brackets), GROUP BY, ORDER BY, LIMIT, OFFSET
- INSERT with field-level and entity-level insertion
- UPDATE with typed column setters and WHERE
- DELETE with WHERE
- Aggregate functions (SUM, AVG, COUNT, MAX, MIN) on fields
- Query forking for dynamic query patterns
- Safety check preventing WHERE-less UPDATE/DELETE
- Code generator producing typed Table subclasses with `fromDb`/`toDb` mapping

## Gap Analysis

### What's missing vs. real-world usage

Stanza currently competes with two alternatives: raw `postgres` v3 (which already has `Sql.named()` with parameter maps) and full ORMs like Drift. To justify adoption, stanza needs to handle the queries people actually write in production — not just the simple CRUD that raw SQL handles fine.

The following gaps are ordered by impact. Items marked **[blocker]** would cause most evaluators to immediately dismiss the package. Items marked **[painful]** force users to drop to raw SQL regularly, undermining the value proposition. Items marked **[expected]** are things people will look for in the README before adopting.

#### [blocker] No JOIN support
Every non-trivial application queries across related tables. Without JOINs, stanza can only query single tables, which means users drop to raw SQL for the majority of real queries. This is the single biggest reason someone would evaluate stanza and pass.

#### [blocker] No RETURNING clause
PostgreSQL's `RETURNING` clause (`INSERT ... RETURNING *`, `UPDATE ... RETURNING id, updated_at`) eliminates a round trip after every write. It's idiomatic PostgreSQL and every competing Dart query builder supports it. Without it, every insert or update that needs the resulting row requires a follow-up SELECT.

#### [blocker] No tests
Zero tests exist. A query builder is uniquely well-suited to unit testing — you can assert on the generated SQL string and substitution map without a database. No tests means no confidence in correctness, no regression safety, and no credibility on pub.dev.

#### [painful] No batch insert
`INSERT INTO ... VALUES (...), (...), (...)` is essential for any bulk data operation. Currently inserting 100 rows requires building and executing 100 separate `InsertQuery` objects. This is orders of magnitude slower than a single batch statement.

#### [painful] No upsert / ON CONFLICT
`INSERT ... ON CONFLICT (key) DO UPDATE SET ...` is one of the most frequently used PostgreSQL patterns — used for idempotent writes, sync operations, and any "create or update" logic. Without it, users must write raw SQL or implement read-then-write with race conditions.

#### [painful] No IN / NOT IN
`WHERE id IN (1, 2, 3)` and `WHERE id NOT IN (...)` are fundamental SQL operations. There's no `isIn()` or `isNotIn()` in `WhereOperation`. Users can't express set-membership queries at all through the builder.

#### [painful] No BETWEEN
`WHERE created_at BETWEEN @start AND @end` is extremely common for date range queries. No `isBetween()` operation exists.

#### [expected] No DISTINCT
`SELECT DISTINCT` is a basic SQL capability. `SelectQuery` has no way to express it.

#### [expected] No HAVING
`GROUP BY ... HAVING COUNT(*) > 5` is incomplete without HAVING. The GROUP BY clause exists but can't be filtered.

#### [expected] No raw SQL escape hatch
When the builder can't express a query, there should be a way to execute arbitrary SQL through the same pool/session/result infrastructure. Something like `stanza.raw<T>(sql, params, table)`.

#### [expected] No SSL/TLS configuration
The `Stanza.tcp()` factory doesn't expose `SslMode` or certificate paths. Production PostgreSQL deployments almost universally require SSL.

#### [expected] Incomplete documentation
The README needs a quick-start guide, API overview, and realistic examples beyond the single Animal entity. Dartdoc comments are inconsistent.

### What's adequate but could improve later

These are nice-to-haves that don't block adoption:

- **Streaming results**: postgres v3 supports cursor-based streaming; useful for large result sets but not required day-one
- **Schema migrations**: competitors offer this but it's a massive scope increase; better as a companion package
- **Multi-entity JOIN mapping**: mapping a single result row to multiple typed objects requires design work; initial JOINs can return raw column maps
- **Connection tuning**: statement cache size, timeouts, connect timeout
- **IS DISTINCT FROM**: PostgreSQL's null-safe equality; niche but useful
- **CASE expressions**: conditional logic in SELECT fields
- **CTEs (WITH clauses)**: common table expressions for complex queries

---

## Implementation Plan

### Phase 1: Foundation & Core Blockers

**Goal:** Establish test coverage for existing code, add the features that would cause immediate rejection, and provide escape hatches. After this phase, stanza can handle real queries and users are never stuck.

#### 1.1 — Test Suite for Existing Functionality

Tests come first. The query builder is uniquely well-suited to unit testing — assert on the generated SQL string and substitution map, no database needed. Having tests before adding features provides regression safety and confirms the existing code actually works as expected.

**Files to create:**
- `test/select_query_test.dart`
- `test/insert_query_test.dart`
- `test/update_query_test.dart`
- `test/delete_query_test.dart`
- `test/where_operations_test.dart`
- `test/field_test.dart`
- `test/sql_injection_test.dart`

**Strategy:**

```dart
// Example test pattern:
test('select with where and limit', () {
  final q = SelectQuery(animalTable)
    ..selectStar()
    ..where(animalTable.legs).isGreaterThan(2)
    ..limit(10);

  expect(q.statement(),
    'SELECT mammal.* FROM mammal WHERE mammal.number_of_legs > @mammal_number_of_legs_0 LIMIT 10');
  expect(q.substitutionValues, {'mammal_number_of_legs_0': 2});
});
```

**Test coverage targets for existing code:**
- Every method on `WhereOperation` (isEqualTo, matches, startsWith, endsWith, contains, isNull, isNotNull, etc.)
- SQL injection payloads in string operations (verify they're parameterized, not interpolated)
- LIKE escape characters (`%`, `_`, `\` in user input)
- All query types: basic, with where, with all clauses combined
- SELECT: fields, star, GROUP BY, ORDER BY, LIMIT, OFFSET, aggregates
- INSERT: field-level, entity-level
- UPDATE: column setters with WHERE
- DELETE: with WHERE, safety check for WHERE-less
- Query forking preserving state
- Edge cases: empty select fields, multiple orderBy

#### 1.2 — JOINs

**Files to create:**
- `lib/src/select/join_clause.dart`

**Design:**

```dart
// Usage target:
var q = SelectQuery(Animal.$table)
  ..selectStar()
  ..selectFields([Owner.$table.name.rename('owner_name')])
  ..innerJoin(Owner.$table).on(Animal.$table.ownerId, Owner.$table.id)
  ..leftJoin(Habitat.$table).on(Animal.$table.habitatId, Habitat.$table.id)
  ..where(Owner.$table.name).matches('alice');
```

Implementation:

```dart
enum JoinType { inner, left, right, cross }

class JoinClause {
  final JoinType type;
  final Table joinTable;
  Field? _leftField;
  Field? _rightField;

  JoinClause(this.type, this.joinTable);

  void on(Field left, Field right) {
    _leftField = left;
    _rightField = right;
  }

  String get clause {
    final keyword = switch (type) {
      JoinType.inner => 'INNER JOIN',
      JoinType.left  => 'LEFT JOIN',
      JoinType.right => 'RIGHT JOIN',
      JoinType.cross => 'CROSS JOIN',
    };
    if (type == JoinType.cross) return '$keyword ${joinTable.$name}';
    return '$keyword ${joinTable.$name} ON ${_leftField!.qualifiedName} = ${_rightField!.qualifiedName}';
  }
}
```

**Files to modify:**
- `select_query.dart`: Add `_joins` list, `innerJoin()`, `leftJoin()`, `rightJoin()`, `crossJoin()` methods, include joins in `statement()` between FROM and WHERE

**Result mapping consideration:**
JOIN results span multiple tables, so `fromDb()` may fail if columns from the joined table don't map to the primary entity. The `QueryResult.all` getter already handles this gracefully (catches exceptions, sets `value` to null). Users can access the raw column map via `result.aggregates` or `result.raw`. A typed multi-entity mapper can be added later.

**SQL output:**
```sql
SELECT mammal.*, owner.name AS owner_name
FROM mammal
INNER JOIN owner ON mammal.owner_id = owner.id
LEFT JOIN habitat ON mammal.habitat_id = habitat.id
WHERE owner.name = @owner_name_0
```

**Tests:** `test/join_test.dart` — inner, left, right, cross, with where on joined table, multiple joins.

#### 1.3 — RETURNING Clause

**Files to create:**
- `lib/src/shared/returning_clause.dart`

**Design:**

```dart
// Usage target:
var q = InsertQuery(Animal.$table)
  ..insertEntity<Animal>(animal)
  ..returning([Animal.$table.id, Animal.$table.createdAt]);

var q2 = UpdateQuery(Animal.$table)
  ..column(Animal.$table.name).string('Lion')
  ..where(Animal.$table.id).isEqualTo(1)
  ..returningStar();

var q3 = DeleteQuery(Animal.$table)
  ..where(Animal.$table.id).isEqualTo(1)
  ..returning([Animal.$table.id]);
```

Implementation:

```dart
class ReturningClause {
  final List<String> _fields = [];
  bool _star = false;

  void addFields(List<Field> fields) {
    for (final f in fields) {
      _fields.add(f.sql);
    }
  }

  void star() => _star = true;

  String get clause => _star ? 'RETURNING *' : 'RETURNING ${_fields.join(', ')}';
}
```

**Files to modify:**
- `insert_query.dart`: Add `returning()` and `returningStar()` methods, append to statement
- `update_query.dart`: Same
- `delete_query.dart`: Same

Apply via a mixin `ReturningMixin` on all three query types to avoid duplication.

**Tests:** `test/returning_test.dart` — RETURNING on insert, update, delete; star vs specific fields.

#### 1.4 — WHERE Clause Additions: IN, NOT IN, BETWEEN

**Files to modify:**
- `where_operations.dart`

New methods on `WhereOperation`:

```dart
/// WHERE field IN (@val_0, @val_1, @val_2)
Query isIn(List<dynamic> values) {
  if (values.isEmpty) {
    throw StanzaException('isIn() requires at least one value.');
  }
  final tokens = <String>[];
  for (var i = 0; i < values.length; i++) {
    final sub = ValueSub('${_subKeyBase}_in_$i', values[i]);
    _where.source.addSubstitution(sub);
    tokens.add(sub.token);
  }
  _raw = '${_where.field.qualifiedName} IN (${tokens.join(', ')})';
  return _attach();
}

/// WHERE field NOT IN (...)
Query isNotIn(List<dynamic> values) { /* mirror of isIn with NOT IN */ }

/// WHERE field BETWEEN @low AND @high
Query isBetween(dynamic low, dynamic high) {
  final subLow = ValueSub('${_subKeyBase}_between_low', low);
  final subHigh = ValueSub('${_subKeyBase}_between_high', high);
  _where.source.addSubstitution(subLow);
  _where.source.addSubstitution(subHigh);
  _comparison = 'BETWEEN';
  _comparable = '${subLow.token} AND ${subHigh.token}';
  return _attach();
}
```

These three operations cover the vast majority of where-clause patterns that are currently impossible to express.

**Tests:** Added to `test/where_operations_test.dart` — isIn with various sizes, isNotIn, isBetween, empty list error.

#### 1.5 — Raw SQL Escape Hatch

This is simple to implement and immediately gives users a workaround for anything the builder can't express yet. Having it early reduces pressure to have every SQL feature perfect before stanza is useful.

Add a `raw()` method to both `Stanza` and `StanzaSession`:

```dart
// Usage target:
var result = await stanza.raw<Animal>(
  'SELECT * FROM mammal WHERE name ILIKE @pattern',
  {'pattern': '%tig%'},
  Animal.$table,  // optional — for entity mapping
);
```

**Files to modify:**
- `stanza.dart`: Add `raw<T>()` method that takes SQL string, parameter map, and optional Table for result mapping
- When `table` is provided, results go through `_toQueryResult<T>()` as normal
- When `table` is null, return raw `List<Map<String, dynamic>>`

#### 1.6 — SSL/TLS Configuration

Most production PostgreSQL requires SSL. If someone evaluates stanza and can't connect to their database, it's effectively a blocker. This is a trivial change — just pass `SslMode` through to the postgres pool config.

Extend `PostgresCredentials` or add a `ConnectionSettings` class:

```dart
// Usage target:
var stanza = Stanza.tcp(creds,
  maxConnections: 10,
  sslMode: SslMode.verifyFull,
);
```

**Files to modify:**
- `stanza.dart`: Pass `pg.ConnectionSettings(sslMode: ...)` to `Pool.withEndpoints()`. Expose `SslMode` enum (re-export from postgres package or wrap it).
- `postgres_credentials.dart`: Optionally add `sslMode` field, or keep it as a separate parameter on the factory.

---

### Phase 2: SQL Completeness

**Goal:** Round out the query builder with the remaining SQL features that production apps need regularly. After this phase, users rarely need to drop to raw SQL.

#### 2.1 — Batch Insert

**Design:**

```dart
// Usage target:
var q = InsertQuery(Animal.$table)
  ..insertEntities<Animal>([tiger, lion, bear]);

// Produces:
// INSERT INTO mammal (name, number_of_legs, color, created_at)
// VALUES (@name_0, @legs_0, @color_0, @created_at_0),
//        (@name_1, @legs_1, @color_1, @created_at_1),
//        (@name_2, @legs_2, @color_2, @created_at_2)
```

**Files to modify:**
- `insert_clause.dart`: Support multiple value tuples, not just one. Internal representation becomes `List<List<String>>` for values.
- `insert_query.dart`: Add `insertEntities<T>(List<T> entities)` method. Each entity generates a value tuple with unique substitution keys (appending index).

The column list is determined by the first entity's `toDb()` keys. All entities must produce the same columns (enforced by the same `Table.toDb()` method).

**Tests:** `test/batch_insert_test.dart` — batch insert with 1, 3, 100 entities.

#### 2.2 — Upsert / ON CONFLICT

**Files to create:**
- `lib/src/insert/conflict_clause.dart`

**Design:**

```dart
// Usage target:
var q = InsertQuery(Animal.$table)
  ..insertEntity<Animal>(animal)
  ..onConflict(
    target: [Animal.$table.name],
    doUpdate: (set) => set
      ..column(Animal.$table.color).string('updated-orange')
      ..column(Animal.$table.legs).number(4),
  )
  ..returning([Animal.$table.id]);

// DO NOTHING variant:
var q2 = InsertQuery(Animal.$table)
  ..insertEntity<Animal>(animal)
  ..onConflictDoNothing(target: [Animal.$table.name]);
```

Implementation:

```dart
typedef ConflictUpdateBuilder = void Function(ConflictSetClause set);

class ConflictClause {
  final List<Field> target;
  final bool doNothing;
  final ConflictSetClause? _setClause;

  ConflictClause.doNothing({required this.target})
      : doNothing = true,
        _setClause = null;

  ConflictClause.doUpdate({
    required this.target,
    required ConflictUpdateBuilder builder,
    required Query source,
  }) : doNothing = false,
       _setClause = ConflictSetClause(source) {
    builder(_setClause!);
  }

  String get clause {
    final targetStr = target.map((f) => f.name).join(', ');
    if (doNothing) return 'ON CONFLICT ($targetStr) DO NOTHING';
    return 'ON CONFLICT ($targetStr) DO UPDATE SET ${_setClause!.clause}';
  }
}
```

**Files to modify:**
- `insert_query.dart`: Add `onConflict()` and `onConflictDoNothing()`, append clause to statement

**Tests:** `test/upsert_test.dart` — DO UPDATE and DO NOTHING variants.

#### 2.3 — DISTINCT and HAVING

**DISTINCT:**

```dart
// Usage target:
var q = SelectQuery(Animal.$table)
  ..distinct()
  ..selectFields([Animal.$table.color]);
```

**Files to modify:**
- `select_query.dart`: Add `bool _distinct = false` flag and `distinct()` setter. In `statement()`, emit `SELECT DISTINCT` when true.

**HAVING:**

```dart
// Usage target:
var q = SelectQuery(Animal.$table)
  ..selectFields([Animal.$table.color, Animal.$table.id.count().rename('count')])
  ..groupBy([Animal.$table.color])
  ..having(Animal.$table.id.count()).isGreaterThan(5);
```

**Files to create:**
- `lib/src/select/having_clause.dart` — mirrors `WhereClause` structure but emits `HAVING` keyword

**Files to modify:**
- `select_query.dart`: Add `having()` method that returns a `WhereOperation` targeting the having clause list. Append HAVING after GROUP BY in `statement()`.

The cleanest implementation is a second `WhereClause`-like mixin or a standalone clause that reuses `WhereOperation` with a different attachment list.

**Tests:** Added to `test/select_query_test.dart` — DISTINCT, HAVING, GROUP BY + HAVING combinations.

---

### Phase 3: Publishing & Ecosystem

**Goal:** Make stanza publishable, discoverable, and maintainable. After this phase, stanza is ready for pub.dev.

#### 3.1 — Documentation

**Files to create/update:**
- `README.md` — complete rewrite:
  - Badges (pub.dev version, build status, coverage)
  - One-paragraph pitch
  - Quick-start (install, annotate, generate, query)
  - API overview with realistic examples
  - Section for each query type with code samples
  - JOIN examples
  - RETURNING examples
  - Connection configuration (SSL, pool size)
  - Comparison with alternatives (when to use stanza vs raw postgres vs Drift)
- `CHANGELOG.md` — version history starting from 0.1.0
- `example/` — expand beyond single Animal class:
  - Multi-entity example with JOINs (e.g. User, Post, Comment)
  - Batch insert example
  - Transaction example

**Dartdoc:**
Review all public APIs for complete doc comments. Priority: `Stanza`, `SelectQuery`, `InsertQuery`, `WhereOperation`, `Field`, `Table`.

#### 3.2 — CI Pipeline

- GitHub Actions workflow:
  - `dart analyze` (zero warnings)
  - `dart test` (all pass)
  - Coverage report (aim for >90%)
  - Run on Dart stable + beta
- Dependabot for dependency updates

#### 3.3 — pub.dev Publishing

- Verify `pubspec.yaml` metadata (homepage, repository, issue_tracker, topics)
- Run `dart pub publish --dry-run`
- Add pub.dev topics: `postgresql`, `query-builder`, `database`, `sql`, `codegen`
- Version: `0.1.0` for initial publish (signal pre-1.0 API instability)

#### 3.4 — Streaming Results

For large result sets, expose postgres v3's cursor support:

```dart
// Usage target:
await for (final row in stanza.stream<Animal>(selectQuery)) {
  process(row);
}
```

This wraps `pool.execute()` with `queryMode: QueryMode.simple` or uses `Cursor` depending on postgres v3's streaming API. Lower priority — most applications don't need this until they're processing thousands of rows.

#### 3.5 — Connection Configuration

Expose additional `pg.PoolSettings` and `pg.ConnectionSettings` options:

```dart
Stanza.tcp(creds,
  maxConnections: 25,
  sslMode: SslMode.verifyFull,
  connectTimeout: Duration(seconds: 15),
  queryTimeout: Duration(seconds: 30),
  applicationName: 'my-app',
);
```

---

## Summary Roadmap

| Phase | Items | Estimated Scope | Result |
|-------|-------|----------------|--------|
| **1: Foundation & Core Blockers** | Tests for existing code, JOINs, RETURNING, IN/BETWEEN, raw SQL, SSL | ~1200-1500 new LOC | Handles real queries, never stuck |
| **2: SQL Completeness** | Batch insert, upsert, DISTINCT/HAVING | ~500-700 new LOC | Rarely need raw SQL |
| **3: Publishing & Ecosystem** | Docs, CI, pub.dev, streaming, config | ~300 new LOC + config | Discoverable and maintainable |

Phase 1 is the minimum to make stanza genuinely useful — tests provide confidence, core SQL features handle real queries, and the raw SQL escape hatch plus SSL ensure users are never blocked. Phase 2 rounds out the SQL feature set. Phase 3 is about polish and long-term viability.
