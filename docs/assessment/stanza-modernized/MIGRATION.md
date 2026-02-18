# Stanza Modernization — Migration Guide

## Overview

This is a complete modernization of stanza from Dart 2.x / pre-null-safety to Dart 3.x with null safety, postgres v3, and modern build_runner tooling.

## What Changed

### 1. Dart 3 + Null Safety
- SDK constraint: `>=3.0.0 <4.0.0`
- All types are null-safe; nullable types use `?` explicitly
- Entity fields should use `late` for mutable properties (see example)
- Collection literals replace `List()` / `Map()` constructors
- `final` used where possible

### 2. postgres v2 → v3 (Breaking)
The entire connection/execution layer was rewritten.

**Old API:**
```dart
var stanza = Stanza(creds);
var connection = await stanza.connection();
await connection.execute(insertQuery, autoClose: false);
var result = await connection.execute<Animal>(selectQuery);
```

**New API:**
```dart
var stanza = Stanza.tcp(creds, maxConnections: 10);

// Single query (pool manages connection):
var result = await stanza.execute<Animal>(selectQuery);

// Multi-query on one session:
await stanza.run((session) async {
  await session.execute(insertQuery);
  return session.execute<Animal>(selectQuery);
});

// Transaction (auto-rollback on failure):
await stanza.runTransaction((session) async {
  await session.execute(insertQuery);
  return session.execute<Animal>(selectQuery);
});

await stanza.close();
```

Key changes:
- `Stanza(creds)` → `Stanza.tcp(creds)` or `Stanza.unix(creds)` (explicit transport)
- No more manual `StanzaConnection` — the pool handles lifecycle
- `StanzaSession` wraps a postgres v3 `Session` for multi-query blocks
- `run()` for session reuse, `runTransaction()` for atomic transactions
- `Pool` from postgres v3 replaces `pool` package dependency

### 3. Connection Pooling
- Removed `pool` package dependency entirely
- Uses `postgres` v3's built-in `Pool.withEndpoints()`
- `maxConnections` parameter on factory constructors (default: 25)
- Instance caching still works via static `_instances` map

### 4. Code Generator (stanza_builder)
- `source_gen: ^2.0.0` (was `^0.9.0`)
- `analyzer: >=6.2.0 <8.0.0` (was `^1.5.0`)
- `build: ^2.4.0` (was `^1.2.2`)
- Generator uses `getDisplayString()` without deprecated params
- Generated code is null-safe with `@override` annotations

### 5. SQL Injection Fix
**Before (vulnerable):** String where-clause operations (`matches`, `startsWith`, `endsWith`, `contains`) used string interpolation directly in SQL:
```dart
// Old: _comparable = "'%$string%'" — SQL injection!
```

**After (safe):** All string operations use parameterized substitutions:
```dart
// New: Uses ValueSub with LIKE escape handling
final escaped = _escapeLikePattern(string);
final sub = ValueSub('${_subKeyBase}_like', '%$escaped%');
_comparable = sub.token;
```

Special LIKE characters (`%`, `_`, `\`) are escaped in user input.

### 6. Cleanup
- Removed `print()` debug statements from `stanza.dart`
- Removed commented-out code from connection handling
- Removed `recase` from stanza runtime (only needed in builder)
- Added `analysis_options.yaml` with recommended lints

## Dependency Summary

| Package | Old | New |
|---------|-----|-----|
| SDK | `>=2.1.0 <3.0.0` | `>=3.0.0 <4.0.0` |
| postgres | `git: stablekernel/postgresql-dart` | `^3.4.0` |
| pool | `^1.4.0` | **removed** |
| recase | `^2.0.0` | `^4.1.0` |
| source_gen | `^0.9.0` | `^2.0.0` |
| analyzer | `^1.5.0` | `>=6.2.0 <8.0.0` |
| build | `^1.2.2` | `^2.4.0` |

## Entity Class Changes

Entity classes need `late` on mutable fields:

```dart
// Before
class Animal {
  int id;
  String name;
  Animal();
}

// After
class Animal {
  late int id;
  late String name;
  Animal();
}
```

## Remaining TODO
- [ ] `dart pub get` + `dart analyze` (couldn't run in sandbox)
- [ ] Run `build_runner` to verify generator output
- [ ] Add unit tests
- [ ] Consider JOIN support (was missing before modernization)
- [ ] Evaluate whether `QueryResult.first` should throw vs return null
