# Stanza

Type-safe, AI-first ORM for Dart. One canonical way to do everything — optimized for LLM code generation. Database-agnostic core with pluggable adapters.

## Design Philosophy

- **Immutable entities, typed columns.** No `late` fields. No stringly-typed `Field('table', 'name')`. Columns are `IntColumn`, `StringColumn`, `DateTimeColumn` with type-appropriate operations.
- **Callback-based column access.** `.where((t) => t.email.equals('x'))` — the callback gives you a typed table descriptor. No raw strings, no column name typos.
- **Expression trees, not string concatenation.** `&` and `|` compose expressions. Parameters are always collected, never interpolated.
- **Generated companions.** `UserInsert` (excludes auto-increment PK), `UserUpdate` (all fields optional), `copyWith` — each operation gets purpose-built types.
- **Safe by default.** UPDATE/DELETE without `.where()` throw. All values parameterized. No SQL injection.
- **One right way.** Every operation has one canonical API. LLMs don't guess between three equivalent patterns.
- **Database-agnostic.** Core query builder works with any SQL database. Adapters handle connection management and dialect differences.

## Features

- Typed columns: `IntColumn`, `StringColumn`, `BoolColumn`, `DoubleColumn`, `DateTimeColumn`
- Fluent query builder: SELECT, INSERT, UPDATE, DELETE with method chaining
- JOINs: INNER, LEFT, RIGHT with typed column conditions
- Aggregates: COUNT, SUM, AVG, MIN, MAX with GROUP BY and HAVING
- Full-text search (PostgreSQL): `to_tsvector`/`tsquery`, ts_rank, ts_headline, multiple languages
- Full-text search (SQLite): FTS5 with MATCH, bm25 ranking, highlight, snippet
- Trigram similarity: fuzzy matching with `pg_trgm` operators (PostgreSQL)
- Subqueries: `WHERE col IN (SELECT ...)`
- ON CONFLICT: upsert with DO UPDATE or DO NOTHING
- Code generation: `@StanzaEntity` + `build_runner` generates table descriptors, companions, schema metadata
- Schema management: diff code vs database, generate forward-only SQL migrations, apply with checksums
- Database adapters: pluggable architecture — PostgreSQL and SQLite adapters included
- Connection pooling: wraps `postgres` v3 with instance caching (via `stanza_postgres`)
- Streaming: row-by-row results without buffering
- Transactions: automatic rollback on error

## Packages

| Package | Purpose |
|---------|---------|
| `stanza` | Core ORM — annotations, columns, expressions, query builder, schema types |
| `stanza_postgres` | PostgreSQL adapter — connection pool, introspection, migrations, CLI |
| `stanza_sqlite` | SQLite adapter — file/memory databases, introspection, migrations, CLI |
| `stanza_builder` | Code generation — `@StanzaEntity` → table descriptors, companions, schema |

## Quick Start

Define an entity:

```dart
import 'package:stanza/stanza.dart';

part 'user.g.dart';

@StanzaEntity()
class User {
  @StanzaKey(autoIncrement: true)
  final int id;

  @StanzaField(length: 100, unique: true)
  final String email;

  final String name;

  @StanzaField(defaultValue: 'now()')
  final DateTime createdAt;

  const User({required this.id, required this.email, required this.name, required this.createdAt});
}
```

Generate and query:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**PostgreSQL:**

```dart
import 'package:stanza_postgres/stanza_postgres.dart';

final db = Stanza.url('postgresql://user:pass@host/dbname');
final users = $UserTable();

final result = await db.execute(
  SelectQuery(users).where((t) => t.email.like('%@example.com')),
);
```

**SQLite:**

```dart
import 'package:stanza_sqlite/stanza_sqlite.dart';

final db = StanzaSqlite.open('app.db');  // or StanzaSqlite.memory() for tests
final users = $UserTable();

final result = await db.execute(
  SelectQuery(users).where((t) => t.email.like('%@example.com')),
);
```

Same query builder, same entity types — swap one import and one connection line.

## Setup

```yaml
dependencies:
  stanza:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza
      ref: dev

  # Pick one (or both) adapters:
  stanza_postgres:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza_postgres
      ref: dev
  stanza_sqlite:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza_sqlite
      ref: dev

dev_dependencies:
  build_runner: ^2.4.0
  stanza_builder:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza_builder
      ref: dev
```

SQLite requires `libsqlite3-dev` (Debian/Ubuntu) or equivalent native library.

## Documentation

- [CLAUDE.md](CLAUDE.md) — Contributor guide (architecture, internals, how to modify the package)
- [docs/guide.md](docs/guide.md) — Consumer reference (complete API, every type and method, copy-paste ready)

## Status

v2 rewrite complete with multi-database adapter support. PostgreSQL and SQLite adapters.

| Package | Tests |
|---------|-------|
| `stanza` (core) | 224 |
| `stanza_sqlite` | 89 |
| `stanza/example` | 20 |

**333 tests total**, zero analysis issues.

### SQLite Limitations

The SQLite adapter supports the full Stanza query builder (SELECT, INSERT, UPDATE, DELETE, JOINs, aggregates, subqueries). Not supported:

- **PostgreSQL FTS / trigram**: `to_tsvector`, `pg_trgm` are PostgreSQL-only (use FTS5 for SQLite full-text search)
- **ILIKE**: use `LIKE` instead (SQLite LIKE is case-insensitive for ASCII by default)
- **ALTER COLUMN migrations**: SQLite only supports `CREATE TABLE` and `ADD COLUMN`. Other schema changes are rendered as TODO comments in migration files.
- **Streaming**: not implemented (SQLite is synchronous FFI)
