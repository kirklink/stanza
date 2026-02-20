# Stanza

Type-safe, AI-first PostgreSQL ORM for Dart. One canonical way to do everything — optimized for LLM code generation.

## Design Philosophy

- **Immutable entities, typed columns.** No `late` fields. No stringly-typed `Field('table', 'name')`. Columns are `IntColumn`, `StringColumn`, `DateTimeColumn` with type-appropriate operations.
- **Callback-based column access.** `.where((t) => t.email.equals('x'))` — the callback gives you a typed table descriptor. No raw strings, no column name typos.
- **Expression trees, not string concatenation.** `&` and `|` compose expressions. Parameters are always collected, never interpolated.
- **Generated companions.** `UserInsert` (excludes auto-increment PK), `UserUpdate` (all fields optional), `copyWith` — each operation gets purpose-built types.
- **Safe by default.** UPDATE/DELETE without `.where()` throw. All values parameterized. No SQL injection.
- **One right way.** Every operation has one canonical API. LLMs don't guess between three equivalent patterns.

## Features

- Typed columns: `IntColumn`, `StringColumn`, `BoolColumn`, `DoubleColumn`, `DateTimeColumn`
- Fluent query builder: SELECT, INSERT, UPDATE, DELETE with method chaining
- JOINs: INNER, LEFT, RIGHT with typed column conditions
- Aggregates: COUNT, SUM, AVG, MIN, MAX with GROUP BY and HAVING
- Full-text search: `to_tsvector`/`tsquery`, ts_rank, ts_headline, multiple languages
- Trigram similarity: fuzzy matching with `pg_trgm` operators
- Subqueries: `WHERE col IN (SELECT ...)`
- ON CONFLICT: upsert with DO UPDATE or DO NOTHING
- Code generation: `@Entity` + `build_runner` generates table descriptors, companions, schema metadata
- Schema management: diff code vs database, generate forward-only SQL migrations, apply with checksums
- Connection pooling: wraps `postgres` v3 with instance caching
- Streaming: row-by-row results without buffering
- Transactions: automatic rollback on error

## Quick Start

Define an entity:

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

Generate, query, insert:

```bash
dart run build_runner build --delete-conflicting-outputs
```

```dart
final users = $UserTable();

// SELECT
final query = SelectQuery(users)
    .where((t) => t.email.like('%@example.com'))
    .orderBy((t) => t.createdAt.desc())
    .limit(10);

// INSERT
final insert = InsertQuery(users)
    .values(UserInsert(email: 'a@b.com', name: 'Kirk').toRow())
    .returning();

// UPDATE
final update = UpdateQuery(users, UserUpdate(name: 'Spock').toRow())
    .where((t) => t.id.equals(1));
```

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

## Documentation

- [CLAUDE.md](CLAUDE.md) — Contributor guide (architecture, internals, how to modify the package)
- [docs/guide.md](docs/guide.md) — Consumer reference (complete API, every type and method, copy-paste ready)

## Status

v2 rewrite complete. All phases implemented:

| Phase | Description | Tests |
|-------|-------------|-------|
| 0 | Branch & scaffold | - |
| 1 | Foundation (annotations, columns, expressions) | 34 |
| 2 | Query builder (SELECT, INSERT, UPDATE, DELETE, JOIN) | 42 |
| 3 | Code generator (entity_generator, type_mapping) | 20 |
| 4 | Connection & execution (Stanza, StanzaSession, TableAccessor) | - |
| 5 | Schema & migrations (diff, introspect, migrate, CLI) | 57 |
| 6a | Aggregates + GROUP BY + HAVING | 30 |
| 6b | Full-text search + trigram similarity | 17 |
| 6c | Subqueries + raw SQL | 5 |

**229 tests total**, zero analysis issues.
