# Stanza: Assessment & Implementation Plan

## Current State

Stanza has been fully modernized to Dart 3, null safety, and postgres v3. All planned phases are complete. The package provides a type-safe PostgreSQL query builder with code generation, covering SELECT, INSERT, UPDATE, DELETE, JOINs, RETURNING, batch insert, upsert, streaming, and more — backed by 173+ unit tests and integration tests against real PostgreSQL.

What exists today:
- SELECT with fields, star, DISTINCT, WHERE (and/or with brackets), GROUP BY, HAVING, ORDER BY, LIMIT, OFFSET
- JOINs: INNER, LEFT, RIGHT, CROSS with typed `@BelongsTo` code generation
- INSERT with field-level, entity-level, and batch insertion
- Upsert: ON CONFLICT DO UPDATE SET / DO NOTHING
- UPDATE with typed column setters and WHERE
- DELETE with WHERE
- RETURNING clause on INSERT, UPDATE, DELETE
- WHERE operations: equality, comparison, LIKE, IN, NOT IN, BETWEEN, IS NULL, date comparisons
- Aggregate functions (SUM, AVG, COUNT, MAX, MIN) on fields
- Streaming results via postgres v3 prepared statements
- Raw SQL escape hatch (`rawExecute`)
- Connection configuration: SSL/TLS, timeouts, application name
- Connection pooling with instance caching
- Sessions and transactions
- Query forking for dynamic query patterns
- Safety check preventing WHERE-less UPDATE/DELETE
- Code generator producing typed Table subclasses with `fromDb`/`toDb` mapping and `@BelongsTo` JOIN helpers

## Gap Analysis (Resolved)

All gaps identified in the original assessment have been addressed:

| Gap | Severity | Resolution |
|-----|----------|------------|
| No JOIN support | blocker | `innerJoin()`, `leftJoin()`, `rightJoin()`, `crossJoin()` on `SelectQuery` (Phase 1.2) |
| No RETURNING clause | blocker | `returning()` and `returningStar()` on INSERT, UPDATE, DELETE (Phase 1.3) |
| No tests | blocker | 173+ unit tests across 11 test files + integration tests (Phase 1.1) |
| No batch insert | painful | `insertEntities<T>(list)` for multi-row INSERT (Phase 2.1) |
| No upsert / ON CONFLICT | painful | `onConflict()` and `onConflictDoNothing()` (Phase 2.2) |
| No IN / NOT IN | painful | `isIn()` and `isNotIn()` on `WhereOperation` (Phase 1.4) |
| No BETWEEN | painful | `isBetween()` on `WhereOperation` (Phase 1.4) |
| No DISTINCT | expected | `distinct()` on `SelectQuery` (Phase 2.3) |
| No HAVING | expected | `having()`, `andHaving()`, `orHaving()` (Phase 2.3) |
| No raw SQL escape hatch | expected | `rawExecute()` on `Stanza` and `StanzaSession` (Phase 1.5) |
| No SSL/TLS configuration | expected | `sslMode` parameter on `Stanza.tcp()`, `SslMode` re-exported (Phase 1.6) |
| Incomplete documentation | expected | Full README rewrite, CHANGELOG, expanded example (Phase 3.1) |

### What could improve in the future

These are nice-to-haves that don't block adoption:

- **Schema migrations**: competitors offer this but it's a massive scope increase; better as a companion package
- **IS DISTINCT FROM**: PostgreSQL's null-safe equality; niche but useful
- **CASE expressions**: conditional logic in SELECT fields
- **CTEs (WITH clauses)**: common table expressions for complex queries
- **Subqueries**: nested SELECT in WHERE or FROM
- **Table aliases for self-joins**: multiple FKs to the same entity type (e.g., `creatorId` and `updaterId` both → User)

---

## Implementation Plan (Complete)

### Phase 1: Foundation & Core Blockers ✅

**Goal:** Establish test coverage for existing code, add the features that would cause immediate rejection, and provide escape hatches.

#### 1.1 — Test Suite ✅

173+ unit tests across 11 test files covering all query types, WHERE operations, JOINs, RETURNING, aggregates, forking, and SQL injection safety. Integration tests run against real PostgreSQL via `DATABASE_URL`.

**Test files:**
- `test/select_query_test.dart` — SELECT, DISTINCT, HAVING
- `test/insert_query_test.dart` — INSERT, batch, ON CONFLICT
- `test/update_query_test.dart` — UPDATE with typed setters
- `test/delete_query_test.dart` — DELETE with WHERE
- `test/where_operations_test.dart` — all comparison methods, IN, BETWEEN, SQL injection
- `test/field_test.dart` — Field accessors, aggregates, expressionName
- `test/join_test.dart` — all join types, BelongsTo helpers
- `test/returning_test.dart` — RETURNING on all write query types
- `test/stanza_test.dart` — connection config, caching, SslMode export
- `test/integration_test.dart` — end-to-end against real PostgreSQL

#### 1.2 — JOINs ✅

`innerJoin()`, `leftJoin()`, `rightJoin()`, `crossJoin()` on `SelectQuery`. Joins appear between FROM and WHERE in the generated SQL. `@BelongsTo` annotation on FK fields generates typed join helpers and result extraction methods via code generation.

#### 1.3 — RETURNING Clause ✅

`returning([fields])` and `returningStar()` as a mixin on INSERT, UPDATE, and DELETE queries.

#### 1.4 — IN, NOT IN, BETWEEN ✅

`isIn(list)`, `isNotIn(list)`, `isBetween(low, high)` on `WhereOperation`. Empty list throws `StanzaException`. All values are parameterized.

#### 1.5 — Raw SQL ✅

`rawExecute(sql, {parameters})` on both `Stanza` and `StanzaSession` for DDL, migrations, or queries not expressible through the builder.

#### 1.6 — SSL/TLS ✅

`SslMode` re-exported from `package:stanza/stanza.dart`. Passed through to `pg.PoolSettings` via `Stanza.tcp()`.

---

### Phase 2: SQL Completeness ✅

**Goal:** Round out the query builder so users rarely need to drop to raw SQL.

#### 2.1 — Batch Insert ✅

`insertEntities<T>(list)` generates multi-row INSERT with unique substitution keys per row. Works with RETURNING and ON CONFLICT.

#### 2.2 — Upsert / ON CONFLICT ✅

`onConflict(target:, doUpdate:)` for DO UPDATE SET with typed column setters. `onConflictDoNothing(target:)` for DO NOTHING. Works with single and batch inserts.

#### 2.3 — DISTINCT and HAVING ✅

`distinct()` flag on `SelectQuery`. `HavingClause` mixin with `having()`, `andHaving()`, `orHaving()` reusing `WhereOperation` for all comparison methods. `Field.expressionName` getter handles aggregate-wrapped field references in HAVING.

---

### Phase 3: Publishing & Ecosystem ✅

**Goal:** Make stanza publishable, discoverable, and maintainable.

#### 3.1 — Documentation ✅

Full README rewrite with quick-start, API reference for all query types, WHERE operations table, JOIN examples (manual and generated), connection configuration, streaming, and fork patterns. CHANGELOG with comprehensive 0.1.0 entry. Expanded example with batch insert, upsert, DISTINCT, HAVING, raw SQL, and fork demos.

#### 3.2 — CI Pipeline ✅

GitHub Actions workflow (`.github/workflows/ci.yml`) with `dart analyze` and `dart test` for both `stanza/` and `stanza_builder/`.

#### 3.3 — pub.dev Prep ✅

`pubspec.yaml` metadata updated: homepage, repository, issue_tracker, topics. `dart pub publish --dry-run` passes for stanza (stanza_builder has expected `path` dependency warning, to be swapped at publish time).

#### 3.4 — Streaming Results ✅

`stream<T>(query)` on both `Stanza` and `StanzaSession`. Uses postgres v3 prepared statements (`prepare()` + `bind()`) for true row-by-row streaming. Each element is a `Result<T>` with `.value` and `.aggregate`. Statement is disposed in a `finally` block.

```dart
await for (final row in stanza.stream<Animal>(selectQuery)) {
  print(row.value?.name);
}
```

#### 3.5 — Connection Configuration ✅

`Stanza.tcp()` accepts `sslMode`, `connectTimeout`, `queryTimeout`, `applicationName` — passed through to `pg.PoolSettings`. `Stanza.unix()` accepts the same minus `sslMode`. `Stanza.url()` parses config from URL query parameters (e.g., `?sslmode=require&application_name=my-app`). URL sanitization strips unrecognized parameters for cloud provider compatibility.

---

## Summary

| Phase | Items | Status |
|-------|-------|--------|
| **1: Foundation & Core Blockers** | Tests, JOINs, RETURNING, IN/BETWEEN, raw SQL, SSL | ✅ Complete |
| **2: SQL Completeness** | Batch insert, upsert, DISTINCT/HAVING | ✅ Complete |
| **3: Publishing & Ecosystem** | Docs, CI, pub.dev prep, streaming, connection config | ✅ Complete |

All three phases are complete. Stanza is ready for pub.dev publishing when the `path` dependency in `stanza_builder` is swapped to a version constraint.
