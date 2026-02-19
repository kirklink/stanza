import 'dart:io';

import 'package:stanza/schema.dart';
import 'package:stanza_example/src/example.dart';

/// Stanza schema migration CLI.
///
/// Usage:
///   dart run bin/migrate.dart status      Show applied and pending migrations
///   dart run bin/migrate.dart diff        Show schema differences (code vs database)
///   dart run bin/migrate.dart generate    Generate a migration .sql file from the diff
///   dart run bin/migrate.dart apply       Apply all pending migration files
///   dart run bin/migrate.dart apply --dry-run   Print SQL without executing
void main(List<String> args) => StanzaCli.run(
      args,
      databaseUrl: Platform.environment['DATABASE_URL']!,
      tables: [Owner.$table, Animal.$table],
    );
