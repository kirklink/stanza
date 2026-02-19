# Stanza Changelog

## 0.1.0

Full modernization: Dart 3, null safety, postgres v3.

### Breaking changes
- Migrated to postgres v3 (`package:postgres ^3.4.0`) with connection pooling
- All APIs updated for Dart 3 / null safety
- `Stanza.tcp()` and `Stanza.unix()` replace old connection constructors
- Query result model changed to `QueryResult<T>` with typed `.value` and `.aggregate`

### New features
- **Connection**: `Stanza.url()` for connection URL strings (Neon, Supabase, etc.) with automatic sanitization of unsupported parameters
- **JOINs**: `innerJoin()`, `leftJoin()`, `rightJoin()`, `crossJoin()` on `SelectQuery`
- **`@BelongsTo` annotation**: Generates typed JOIN helpers (`innerJoinOwner()`, `leftJoinOwner()`) and result extraction (`ownerFromRow()`) via code generation
- **RETURNING clause**: `returning([fields])` and `returningStar()` on INSERT, UPDATE, DELETE
- **Batch insert**: `insertEntities<T>(list)` for multi-row INSERT in a single statement
- **Upsert**: `onConflict(target:, doUpdate:)` for ON CONFLICT DO UPDATE SET, `onConflictDoNothing()` for DO NOTHING
- **WHERE operations**: `isIn()`, `isNotIn()`, `isBetween()` on `WhereOperation`
- **DISTINCT**: `distinct()` on `SelectQuery`
- **HAVING**: `having()`, `andHaving()`, `orHaving()` for aggregate filtering after GROUP BY
- **Streaming**: `stream<T>()` on `Stanza` and `StanzaSession` for row-by-row streaming via postgres v3 prepared statements
- **Raw SQL**: `rawExecute()` on `Stanza` and `StanzaSession` for DDL, migrations, or unsupported queries
- **Safety**: UPDATE/DELETE without WHERE throws unless `overrideSafety: true`
- **Query forking**: `fork()` creates deep copies of any query for dynamic patterns

### Code generation
- `@StanzaEntity(name:, snakeCase:, readOnly:)` — class-level table mapping
- `@StanzaField(readOnly:, name:, ignore:)` — field-level column mapping
- `@BelongsTo(ParentType)` — foreign key relationship with typed JOIN helpers

### Connection configuration
- `Stanza.tcp()` accepts `sslMode`, `connectTimeout`, `queryTimeout`, `applicationName`
- `Stanza.unix()` accepts `connectTimeout`, `queryTimeout`, `applicationName`
- `SslMode` re-exported from `package:stanza/stanza.dart`

### Test suite
- 173 unit tests covering all query types, WHERE operations, JOINs, aggregates, streaming, forking
- Integration tests against real PostgreSQL (Neon) via `DATABASE_URL`

---

## 0.0.23
- Change initialization API to make it more clear which cached connection is being called

## 0.0.22
- Upgrade postgres dependency version

## 0.0.21
- Fix bug when throwing entity exception

## 0.0.20
- Make entity exceptions class specific (i.e., ClassNameEntityException)

## 0.0.19
- Clean up minor code generator code

## 0.0.18
- Add readOnly option to StanzaEntity

## 0.0.17
- Bug fix

## 0.0.16
- Add ignore option to StanzaField

## 0.0.15
- Update dependencies

## 0.0.13
- Fixed issue in where clauses with substitution values not allowing periods in qualified field names.

## 0.0.12
- Fixed date comparisons in where clauses.
- Added raw string condition for where clauses.

## 0.0.11
- Removed unused dependency

## 0.0.10
- Added changelog!
- Added example
