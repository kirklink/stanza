# stanza_builder

Code generator companion for the [stanza](https://github.com/kirklink/stanza) PostgreSQL query builder. Generates type-safe table interfaces from annotated Dart classes using `source_gen` and `build_runner`.

## Setup

Add as a dev dependency alongside `build_runner`:

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  stanza_builder:
    git:
      url: https://github.com/kirklink/stanza
      path: stanza_builder
      ref: feature/modernization
```

## Usage

Annotate your model classes and run code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

See the [stanza README](https://github.com/kirklink/stanza/tree/feature/modernization/stanza#readme) for full documentation.