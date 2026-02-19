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
- **Full-text search**: `fullTextMatches()` on `WhereOperation` with configurable language (`FtsConfig`) and query parser (`FtsQueryType`: plain, websearch, phrase)
- **Trigram similarity**: `isSimilarTo()` and `isWordSimilarTo()` on `WhereOperation` for fuzzy matching via `pg_trgm`
- **Search ranking**: `selectRank()` adds `ts_rank()` to SELECT with automatic ORDER BY, `selectHeadline()` adds `ts_headline()` for highlighted snippets
- **Similarity scoring**: `selectSimilarity()` adds `similarity()` score to SELECT, `orderByDistance()` uses GiST-index-friendly `<->` operator
- **Expression support**: `addExpression()` on `SelectClause` and `OrderByClause` for raw SQL expressions in SELECT and ORDER BY
- **DISTINCT**: `distinct()` on `SelectQuery`
- **HAVING**: `having()`, `andHaving()`, `orHaving()` for aggregate filtering after GROUP BY
- **Streaming**: `stream<T>()` on `Stanza` and `StanzaSession` for row-by-row streaming via postgres v3 prepared statements
- **Raw SQL**: `rawExecute()` on `Stanza` and `StanzaSession` for DDL, migrations, or unsupported queries
- **Safety**: UPDATE/DELETE without WHERE throws unless `overrideSafety: true`
- **Query forking**: `fork()` creates deep copies of any query for dynamic patterns

### Schema management
- **Schema diffing**: Compares Dart model annotations against live `information_schema` to detect differences
- **Migration generation**: `SchemaManager.generate()` writes timestamped `.sql` files with `BEGIN`/`COMMIT` wrapping
- **Migration runner**: Forward-only migration application with `_stanza_migrations` tracking table and SHA-256 checksum verification
- **CLI helper**: `StanzaCli.run()` provides `status`, `diff`, `generate`, `apply`, and `apply --dry-run` commands
- **Diff operations**: `CreateTable`, `AddColumn`, `AlterColumnType`, `AlterColumnNullability`, `AlterColumnDefault`, `AddConstraint`, `DropColumn` (safety-commented), `DropConstraint`
- **DB introspector**: Queries `information_schema` for columns, PK/UNIQUE constraints, and foreign keys with serial detection
- **Topological sort**: Tables sorted by FK dependencies (Kahn's algorithm) so parent tables are created before children
- Separate barrel export: `import 'package:stanza/schema.dart'`

### Code generation
- `@StanzaEntity(name:, snakeCase:, readOnly:)` — class-level table mapping
- `@StanzaField(readOnly:, name:, ignore:, type:, nullable:, unique:, defaultValue:)` — field-level column mapping with schema metadata
- `@PrimaryKey(serial:)` — primary key annotation (serial auto-increment by default)
- `@BelongsTo(ParentType, onDelete:)` — foreign key relationship with typed JOIN helpers and referential action
- Generated `$schema` getter on each table class encodes full column/constraint metadata for schema diffing

### Connection configuration
- `Stanza.tcp()` accepts `sslMode`, `connectTimeout`, `queryTimeout`, `applicationName`
- `Stanza.unix()` accepts `connectTimeout`, `queryTimeout`, `applicationName`
- `SslMode` re-exported from `package:stanza/stanza.dart`

### Test suite
- 271 unit tests covering all query types, WHERE operations, JOINs, aggregates, FTS, trigram similarity, streaming, forking, schema model, diff engine, and migration file generation
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
