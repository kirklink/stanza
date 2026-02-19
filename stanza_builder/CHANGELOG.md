# stanza_builder Changelog

## 0.1.0

Full modernization: Dart 3, null safety, updated analyzer/source_gen/build dependencies.

### Breaking changes
- Updated to Dart 3 / null safety
- Minimum analyzer `>=6.2.0`, source_gen `>=2.0.0`, build `>=2.4.0`

### New features
- **`@BelongsTo(ParentType)` annotation**: Generates typed JOIN helpers on the table class:
  - `innerJoin{RelName}(SelectQuery q)` — adds aliased SELECT fields and INNER JOIN clause
  - `leftJoin{RelName}(SelectQuery q)` — same with LEFT JOIN
  - `{relName}FromRow(Map<String, dynamic> row)` — extracts typed parent entity from aliased columns
- Relationship name derived from field name (`ownerId` → `Owner`, `creatorId` → `Creator`)
- Column aliasing uses `{tableName}__{columnName}` double-underscore convention
- Validates parent type has `@StanzaEntity`, target key exists, no duplicate parent types

### Existing features
- `@StanzaEntity(name:, snakeCase:, readOnly:)` — class-level table mapping
- `@StanzaField(readOnly:, name:, ignore:)` — field-level column mapping
- Generates `Table<T>` subclass with `Field` accessors, `fromDb()`, `toDb()`
