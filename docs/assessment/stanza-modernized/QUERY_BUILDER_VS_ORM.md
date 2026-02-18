# Stanza: Query Builder vs ORM

## Where stanza sits today

Stanza is a **query builder with object mapping**. It generates typed field accessors and handles serialization between Dart classes and database rows, but it has no understanding of the relationships between entities, no awareness of object identity, and no lifecycle management. You build queries, execute them, and get objects back.

## What would cross the line into ORM territory

The distance between "query builder with object mapping" and "ORM" comes down to a handful of specific capabilities. Some are large in scope, some are conceptually simple but architecturally invasive.

### 1. Relationships as a first-class concept

This is the biggest single change. Right now, if an `Animal` has an `ownerId` field, stanza has no idea that field points to the `Owner` table. It's just an `int`. An ORM would let you declare the relationship:

```dart
@StanzaEntity()
class Animal {
  late int id;
  late String name;

  @BelongsTo(Owner)
  late int ownerId;

  @HasMany(Vaccination)
  late List<Vaccination> vaccinations;  // not a stored column — a declared relationship
}
```

The generator would then produce:
- JOIN helpers that understand the foreign key path between entities
- Eager loading methods (fetch an `Animal` with its `Owner` in one query)
- Lazy loading methods (fetch the `Owner` on first access)
- Cascade awareness (what happens to `Vaccination` records when an `Animal` is deleted)

This requires the generator to understand your **data model** — the graph of entities and their connections — not just individual tables in isolation.

### 2. Identity map / unit of work

A query builder returns a new `Animal` instance every time you query the same row. Two calls that both fetch row `id=5` produce two unrelated objects.

An ORM tracks that row `id=5` is already loaded and returns the same instance (or at least recognizes it as the same entity). This is typically implemented as a session-scoped identity map:

```dart
final a1 = await session.find<Animal>(5);
final a2 = await session.find<Animal>(5);
identical(a1, a2); // true in an ORM, false in a query builder
```

This enables change tracking and prevents conflicting writes to the same row within a single unit of work.

### 3. Change tracking

Instead of manually building an `UpdateQuery` with the fields you want to change, you'd modify the object directly and let the ORM figure out the minimal UPDATE:

```dart
final animal = await stanza.find<Animal>(5);
animal.name = 'Lion';
await stanza.save(animal);
// Generates: UPDATE mammal SET name = @name_0 WHERE id = @id_1
// Only the dirty field (name) is included in SET
```

Implementation approaches:
- **Snapshot comparison**: Store a copy of the original state at load time, diff against current state at save time
- **Proxy objects**: Wrap entities in a proxy that intercepts setter calls and records changes
- **Dirty flag map**: Track which fields have been modified via a companion metadata object

Each has trade-offs in complexity, performance, and how natural the API feels. Snapshot comparison is the simplest and most common in non-reflection languages like Dart.

### 4. Schema migrations

Once the package understands the full entity model (fields, types, relationships, constraints), it can diff that model against the current database schema and generate migration SQL:

```
$ dart run stanza migrate
> Detected changes:
>   + Added column 'habitat_id' to 'mammal'
>   + Created table 'habitat' (id, name, climate)
>   + Added foreign key mammal.habitat_id -> habitat.id
> Generated: migrations/2026_02_14_add_habitat.sql
```

This is a large feature. Drift has it. JAO has it (Django-style CLI). It's what users expect from a package that calls itself an ORM. It also requires getting into the business of parsing and understanding PostgreSQL schemas, handling edge cases around column type changes, data backfills, and rollback safety.

### 5. Cascade operations

Relationship awareness enables cascade behavior:
- Delete an `Owner` and their `Animal` records are handled according to the relationship rules (cascade delete, set null, restrict, etc.)
- Insert an `Animal` with a nested `Owner` object and the ORM inserts both in the correct order, wiring up the foreign key automatically
- Update a parent entity and have dependent entities refreshed or invalidated

This requires the package to understand operation ordering, foreign key constraints, and potentially topological sorting of entity graphs for multi-table writes.

## What stanza already has that ORMs need

Not starting from zero — several ORM prerequisites are already in place:

- **Entity ↔ table mapping** via `@StanzaEntity` annotations
- **Typed field accessors** generated as `Field` getters on the table class
- **Automatic serialization** via generated `fromDb()` and `toDb()` methods
- **Code generation infrastructure** via `build_runner` and `source_gen`
- **Connection and session management** with transaction support

## The recommendation: don't become an ORM

The competitive analysis shows that stanza's unoccupied niche is specifically the **type-safe query builder** space. Drift already dominates the ORM-like space in Dart and has years of development, extensive documentation, and community behind it.

Becoming a full ORM would mean:
- Competing head-to-head with Drift on its home turf
- Taking on roughly 10x the current scope (identity maps, change tracking, migrations, cascades, lazy loading, relationship resolution)
- Abandoning the "lightweight and predictable" positioning that differentiates stanza
- Inheriting all the complexity and magic that makes ORMs divisive — many developers specifically choose query builders *because* they don't want an ORM

## The middle ground: relationship-aware query builder

There's a more interesting path between pure query builder and full ORM. Add **relationship awareness** to the generator so that JOINs and related-entity queries can be expressed naturally, without adding identity tracking, change tracking, or lifecycle management.

### What this would look like

**Declare relationships in annotations:**

```dart
@StanzaEntity(snakeCase: true)
class Animal {
  @StanzaField(readOnly: true)
  late int id;
  late String name;

  @StanzaRelation(Owner, foreignKey: 'owner_id')
  late int ownerId;
}

@StanzaEntity(snakeCase: true)
class Owner {
  @StanzaField(readOnly: true)
  late int id;
  late String name;
}
```

**Generator produces join-aware helpers:**

```dart
// Generated:
class _$AnimalTable extends Table<Animal> {
  // ... existing fields ...

  /// Join to owner via owner_id -> owner.id
  JoinTarget<Owner> get owner => JoinTarget(
    this, _$OwnerTable(), 
    fromField: 'owner_id', toField: 'id',
  );
}
```

**Ergonomic join queries:**

```dart
var q = SelectQuery(Animal.$table)
  ..selectStar()
  ..selectFields([Animal.$table.owner.name.rename('owner_name')])
  ..join(Animal.$table.owner)  // knows the join path from the annotation
  ..where(Animal.$table.owner.name).matches('alice');
```

**What this gives you:**
- Compile-time verified join paths (misspelling a relationship is a compile error)
- No manual `ON` clause — the generator knows the foreign key mapping
- Natural, discoverable API via IDE autocomplete on `Animal.$table.owner`
- Multi-entity result mapping when relationship metadata is available

**What this explicitly does NOT include:**
- No identity map or session-scoped caching
- No change tracking or dirty detection
- No `save()` method that auto-generates SQL
- No lazy loading or proxy objects
- No schema migrations
- No cascade operations

This keeps stanza in the query builder category while giving it the ergonomic advantage of declared relationships. The SQL it generates remains completely predictable and inspectable. You still build queries explicitly — the package just makes it easier to express queries that span related entities.

This is the positioning that no one else in the Dart ecosystem currently occupies: **a relationship-aware, type-safe, PostgreSQL-specific query builder that works from your existing Dart classes**.
