import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:stanza/src/builder/stanza_entity_generator.dart';

Builder StanzaEntityBuilder(BuilderOptions options) =>
    SharedPartBuilder([StanzaEntityGenerator()], 'stanza_entity_builder');