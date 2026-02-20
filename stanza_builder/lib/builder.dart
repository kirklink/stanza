/// Code generation entry point for `build_runner`.
///
/// Registered in `build.yaml` and invoked automatically by `dart run build_runner`.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/entity_generator.dart';

/// Creates the Stanza entity builder.
///
/// Processes `@Entity` annotations and generates table descriptors,
/// insert/update companions, and `copyWith` extensions.
Builder stanzaBuilder(BuilderOptions options) =>
    SharedPartBuilder([EntityGenerator()], 'stanza');
