# Stanza Modernization Strategy

## Context

`stanza` is a Dart PostgreSQL query builder with two packages in a mono-repo:
- **stanza/** — runtime library (query building, connection, execution)
- **stanza_builder/** — code generator (annotation → typed table classes via `build_runner`)

The packages have been dormant since 2020. They target Dart 2.x (pre-null-safety), depend on a deprecated postgres driver (v2, StableKernel fork), and use outdated versions of source_gen/analyzer/build. The goal is a full modernization to Dart 3, postgres v3, and current build tooling.

A complete reference implementation of the modernized code has been provided alongside this document. Use it as the authoritative source for the target state. The files are in `stanza/` and `stanza_builder/` directories next to this document.

## Repository Setup

The source repo is `kirklink/stanza`. Use the `upgrade` branch as the starting point — it's the most advanced branch with partial dependency work already attempted.

```
git clone https://github.com/kirklink/stanza.git
cd stanza
git checkout upgrade
```

The repo layout is:
```
stanza/              # runtime package
  lib/
    src/
      select/        # SelectQuery, clauses
      insert/        # InsertQuery, InsertClause
      update/        # UpdateQuery, SetClause
      delete/        # DeleteQuery
      shared/        # WhereClause mixin, WhereOperation, WherePackage
      annotations.dart
      field.dart
      table.dart
      query.dart
      query_clause.dart
      query_result.dart
      stanza.dart          # Main class + StanzaConnection
      stanza_exception.dart
      postgres_credentials.dart
      value_substitution.dart
    stanza.dart            # barrel export
    annotations.dart       # barrel export
  example/
stanza_builder/      # code generator package
  lib/
    src/
      stanza_builder.dart
      stanza_entity_generator.dart
      stanza_builder_exception.dart
    stanza_builder.dart    # barrel export
  build.yaml
```

## Migration Phases

Execute these in order. Each phase should leave the code in a compilable state (or close to it) before moving on.

---

### Phase 1: Update pubspec constraints and dependencies

**stanza/pubspec.yaml:**
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  postgres: ^3.4.0
  # REMOVE: pool (postgres v3 has built-in pooling)
  # REMOVE: recase (only needed in builder, not runtime)
dev_dependencies:
  build_runner: ^2.4.0
  lints: ^4.0.0
```

**stanza_builder/pubspec.yaml:**
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  stanza:
    path: ../stanza
  source_gen: ^2.0.0
  build: ^2.4.0
  analyzer: '>=6.2.0 <8.0.0'
  recase: ^4.1.0
dev_dependencies:
  build_runner: ^2.4.0
```

Add `analysis_options.yaml` to stanza/:
```yaml
include: package:lints/recommended.yaml
```

Run `dart pub get` in both packages to verify resolution.

---

### Phase 2: Null safety migration (all source files)

Apply these mechanical changes across every `.dart` file in both packages:

1. **Nullable types**: Add `?` to any field/parameter/return type that can be null. Key spots:
   - `WhereOperation` internal fields (`_comparison`, `_comparable`, `_fieldPreModifier`, `_fieldPostModifier`, `_raw`, `_caseSensitive`) → all `String?` / `bool?`
   - `SelectQuery` optional clauses (`_groupByClause`, `_limitClause`, `_offsetClause`) → nullable
   - `QueryResult.first` returns `Result<T>?`
   - `Result.value` is `T?` (partial selects may not hydrate)
   - `whereClauses` getter returns `String?`
   - `StanzaEntity` annotation: `name` is `String?`
   - `StanzaField` annotation: `name` is `String?`

2. **`late` keyword**: Entity class fields in the example should use `late` for mutable properties that are set after construction (e.g. `late int id; late String name;`).

3. **Collection literals**: Replace any `List()` with `[]`, `Map()` with `{}`.

4. **`final` where possible**: Prefer `final` for local variables and fields that don't change.

5. **Annotation classes**: Add `const` constructors, use named parameters with defaults:
   ```dart
   class StanzaEntity {
     final String? name;
     final bool snakeCase;
     final bool readOnly;
     const StanzaEntity({this.name, this.snakeCase = false, this.readOnly = false});
   }
   ```

Run `dart analyze` after this phase to find remaining null-safety issues.

---

### Phase 3: Rewrite Stanza + StanzaConnection for postgres v3

This is the largest single change. The old architecture was:

```
Stanza (holds creds + pool) → StanzaConnection (wraps PostgreSQLConnection) → execute()
```

The new architecture is:

```
Stanza (holds pg.Pool) → execute() / run() / runTransaction()
                        └→ StanzaSession (wraps pg.Session, used inside run/runTransaction blocks)
```

**Delete entirely:**
- `lib/src/connection.dart` (StanzaConnection class) — replaced by StanzaSession + pool

**Rewrite `lib/src/stanza.dart`:**

Key design decisions in the reference implementation:
- `Stanza._(pool)` private constructor; public factories `Stanza.tcp()` and `Stanza.unix()`
- Uses `pg.Pool.withEndpoints()` with `pg.Endpoint` and `pg.PoolSettings`
- `execute<T>(query)` — single query, pool auto-manages connection
- `run<T>((session) => ...)` — multiple queries on one connection
- `runTransaction<T>((session) => ...)` — atomic transaction with auto-rollback
- `StanzaSession` wraps `pg.Session`, has its own `execute<T>()`
- Instance caching via static `_instances` map (keyed by `host:port|db`)
- Safety check: UPDATE/DELETE without WHERE throws unless `overrideSafety: true`

**Query execution — postgres v3 API:**
```dart
final result = await pool.execute(
  pg.Sql.named(query.statement()),
  parameters: query.substitutionValues,
);
```

**Result conversion — postgres v3 returns `Result` with `ResultRow`:**
```dart
QueryResult<T> _toQueryResult<T>(pg.Result result, Query query) {
  final rows = <Map<String, dynamic>>[];
  for (final row in result) {
    rows.add(row.toColumnMap());
  }
  return QueryResult<T>(rows, query.table);
}
```

The old code used `mappedResultsQuery()` which returned `List<Map<String, Map<String, dynamic>>>` (table-keyed). postgres v3's `toColumnMap()` returns flat `Map<String, dynamic>` (column-keyed). The `QueryResult` and `Table.fromDb()` already expect flat column maps, so this is a clean fit.

**Update barrel export (`lib/stanza.dart`):**
- Remove any export of `connection.dart`
- Ensure all query types, Table, Field, QueryResult, StanzaException, PostgresCredentials are exported

---

### Phase 4: Fix SQL injection in WhereOperation string methods

**File:** `lib/src/shared/where_operations.dart`

The old code for `matches`, `startsWith`, `endsWith`, `contains` used raw string interpolation:
```dart
// VULNERABLE — old code
Query contains(String string, {bool caseSensitive = false}) {
  _comparison = 'LIKE';
  _comparable = "'%$string%'";  // Direct interpolation!
  ...
}
```

**Fix:** Use `ValueSub` for parameterized substitution, and escape LIKE special characters:

```dart
static String _escapeLikePattern(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

Query contains(String string, {bool caseSensitive = false}) {
  _comparison = 'LIKE';
  final escaped = _escapeLikePattern(caseSensitive ? string : string.toLowerCase());
  final sub = ValueSub('${_subKeyBase}_like', '%$escaped%');
  _comparable = sub.token;
  _caseSensitive = caseSensitive;
  return _attach(substitution: sub);
}
```

Apply the same pattern to `startsWith` (prefix `$escaped%`), `endsWith` (`%$escaped`), and `matches` (exact match, no LIKE needed — just use `=` with a ValueSub).

See the reference implementation for the complete file.

---

### Phase 5: Update the code generator (stanza_builder)

**File:** `lib/src/stanza_entity_generator.dart`

The main changes are API compatibility with source_gen ^2.0.0 and analyzer 6+:

1. `element` is already typed correctly in `GeneratorForAnnotation.generateForAnnotatedElement` — just check `element is! ClassElement`.

2. `field.type.getDisplayString()` — in older analyzer versions this required a `withNullability` parameter. In analyzer 6+ this parameter was removed; the method returns the null-safe display string by default. **Remove any `withNullability` argument if present.**

3. `ConstantReader` API is the same — use `annotation.peek('name')?.stringValue` etc.

4. The generated code should include `@override` annotations on `$name`, `$type`, `fromDb`, `toDb`.

5. **build.yaml**: Update the builder configuration:
   ```yaml
   builders:
     stanza_entity:
       target: ":stanza_builder"
       import: "package:stanza_builder/src/stanza_builder.dart"
       builder_factories: ["stanzaBuilder"]
       build_extensions: {".dart": [".stanza.g.part"]}
       auto_apply: dependents
       build_to: cache
       applies_builders: ["source_gen|combining_builder"]
   ```

6. Entry point uses `SharedPartBuilder`:
   ```dart
   Builder stanzaBuilder(BuilderOptions options) =>
       SharedPartBuilder([StanzaEntityGenerator()], 'stanza_entity');
   ```

---

### Phase 6: Cleanup

1. **Remove `print()` statements** from `stanza.dart` — the old code had debug prints for connection events.

2. **Remove commented-out code** in `connection.dart` (this file is deleted in Phase 3 anyway).

3. **Remove `pool` import/dependency** — fully replaced by postgres v3 built-in pool.

4. **Remove `recase` from stanza runtime** — it's only used in the builder package.

5. **Update example** (`example/lib/src/example.dart`):
   - Use `late` on entity fields
   - Use `Stanza.tcp(creds)` instead of `Stanza(creds)`
   - Use `stanza.execute()` directly instead of getting a connection first
   - Show `run()` and `runTransaction()` patterns
   - Update example pubspec SDK to `>=3.0.0 <4.0.0`

---

## Verification Checklist

After all phases, run:

```bash
cd stanza && dart pub get && dart analyze
cd ../stanza_builder && dart pub get && dart analyze
cd ../stanza/example && dart pub get && dart run build_runner build
```

Check that:
- [ ] `dart analyze` reports zero issues in both packages
- [ ] `build_runner build` generates the expected `.g.dart` file
- [ ] Generated code matches the pattern in `example/lib/src/example.g.dart`
- [ ] No `print()` debug statements remain
- [ ] No string interpolation in SQL WHERE clauses (grep for `'%$` and `$string`)
- [ ] All `pool` package references are gone
- [ ] `StanzaConnection` class is gone

## Key API Mapping (Old → New)

| Old (postgres v2) | New (postgres v3) |
|---|---|
| `PostgreSQLConnection(host, port, db, username:, password:)` | `pg.Endpoint(host:, port:, database:, username:, password:)` |
| `connection.open()` | Pool handles this automatically |
| `connection.mappedResultsQuery(sql, substitutionValues:)` | `pool.execute(pg.Sql.named(sql), parameters:)` |
| `connection.close()` | `pool.close()` |
| `Pool(PostgreSQLConnection, ...)` from `pool` package | `pg.Pool.withEndpoints([endpoint], settings:)` |
| Result: `List<Map<String, Map<String, dynamic>>>` | Result: `ResultRow` with `.toColumnMap()` → `Map<String, dynamic>` |

## File-by-File Reference

Every file in the reference implementation has been written and is ready to use. If you need to verify or compare your changes, the reference files are the authoritative target state. The complete file list:

### stanza/ (runtime)
- `pubspec.yaml` — deps and SDK constraint
- `analysis_options.yaml` — lints
- `lib/stanza.dart` — barrel export
- `lib/annotations.dart` — barrel export for annotation users
- `lib/src/annotations.dart` — StanzaEntity, StanzaField
- `lib/src/stanza.dart` — **Stanza, StanzaSession** (biggest rewrite)
- `lib/src/stanza_exception.dart`
- `lib/src/postgres_credentials.dart`
- `lib/src/table.dart` — abstract Table<T>
- `lib/src/field.dart` — Field with aggregates
- `lib/src/query.dart` — abstract Query base
- `lib/src/query_clause.dart` — QueryClause interface
- `lib/src/query_result.dart` — Result<T>, QueryResult<T>
- `lib/src/value_substitution.dart` — ValueSub
- `lib/src/shared/where_package.dart`
- `lib/src/shared/where_clause.dart` — WhereClause mixin
- `lib/src/shared/where_operations.dart` — **SQL injection fix here**
- `lib/src/select/select_query.dart`
- `lib/src/select/select_clause.dart`
- `lib/src/select/group_by_clause.dart`
- `lib/src/select/order_by_clause.dart`
- `lib/src/select/limit_clause.dart`
- `lib/src/select/offset_clause.dart`
- `lib/src/insert/insert_query.dart`
- `lib/src/insert/insert_clause.dart`
- `lib/src/update/update_query.dart`
- `lib/src/update/set_clause.dart` — SetClause + SetValue
- `lib/src/delete/delete_query.dart`
- `example/pubspec.yaml`
- `example/lib/src/example.dart`
- `example/lib/src/example.g.dart`

### stanza_builder/ (generator)
- `pubspec.yaml`
- `build.yaml`
- `lib/stanza_builder.dart` — barrel export
- `lib/src/stanza_builder.dart` — entry point / builder factory
- `lib/src/stanza_entity_generator.dart` — **generator rewrite**
- `lib/src/stanza_builder_exception.dart`
