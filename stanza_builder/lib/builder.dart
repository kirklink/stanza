import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/entity_generator.dart';

Builder stanzaBuilder(BuilderOptions options) =>
    SharedPartBuilder([EntityGenerator()], 'stanza');
