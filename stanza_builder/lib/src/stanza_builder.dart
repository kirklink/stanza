import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:stanza_builder/src/stanza_entity_generator.dart';

Builder StanzaBuilder(BuilderOptions options) =>
    SharedPartBuilder([StanzaEntityGenerator()], 'stanza_builder');