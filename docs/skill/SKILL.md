---
name: stanza-guide
description: "Stanza consumer API reference — database-agnostic ORM with code generation. TRIGGER when: writing database queries, defining @Entity/@Field/@PrimaryKey/@References models, using SelectQuery/InsertQuery/UpdateQuery/DeleteQuery, connecting via StanzaPostgres or StanzaSqlite, running schema migrations, using full-text search (tsvector/FTS5), or configuring stanza_builder code gen."
---

# Stanza — Consumer Guide

Type-safe, database-agnostic ORM for Dart. Four packages: stanza (core), stanza_postgres, stanza_sqlite, stanza_builder.

**Import:** `package:stanza/stanza.dart` + adapter package

## When to use this skill

Use when writing code that **uses** Stanza for database access — entity models, queries, migrations, connections. For editing Stanza internals, the contributor guide loads automatically.

## Guide contents

Full reference in [guide.md](guide.md). Key sections:

- **Setup** — pubspec dependencies for each adapter
- **Quick Start** — entity definition through query execution
- **Annotations** — @Entity, @Field, @PrimaryKey, @References
- **Generated Code** — table descriptors, companions, copyWith
- **Columns & Expressions** — typed column API, expression composition
- **SELECT/INSERT/UPDATE/DELETE** — query builder APIs
- **JOINs** — inner, left, right, cross joins
- **Aggregates, GROUP BY, HAVING** — aggregate functions
- **Full-Text Search** — PostgreSQL tsvector + SQLite FTS5 + trigram similarity
- **Subqueries** — scalar, EXISTS, IN subqueries
- **Connection** — PostgreSQL pool + SQLite file/memory
- **Schema Management** — diff, generate, apply migrations
- **QueryResult, TableAccessor** — result handling
