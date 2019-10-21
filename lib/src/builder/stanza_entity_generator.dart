import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:source_gen/source_gen.dart';
import 'package:recase/recase.dart';

import 'package:stanza/src/annotations/annotations.dart';

final _checkForStanzaField = const TypeChecker.fromRuntime(StanzaField);

class StanzaEntityGenerator extends GeneratorForAnnotation<StanzaEntity> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    var buf = StringBuffer();
    var tableName = annotation.peek('name')?.stringValue ?? '${element.name}';
    if (element is! ClassElement) {
      throw('StanzaEntity must only annotate a class.');
    }
    var fileBuffer = StringBuffer();
    var fieldsBuffer = StringBuffer();
    var tableBuffer = StringBuffer();
    var fieldsClassName = "\$${element.name}Fields";
    fieldsBuffer.writeln("class ${fieldsClassName} {");
    tableBuffer.writeln("class \$${element.name}Entity {");
    tableBuffer.writeln("final String name = '$tableName';");
    tableBuffer.writeln("final $fieldsClassName fields = $fieldsClassName();\n");
    var fromDbBuffer = StringBuffer();
    var toDbBuffer = StringBuffer();
    fromDbBuffer.writeln("${element.name} fromDb(Map<String, dynamic> map) {");
    fromDbBuffer.writeln("return ${element.name}()");
    toDbBuffer.writeln("Map<String, dynamic> toDb(${element.name} instance) {");
    toDbBuffer.writeln("return <String, dynamic>{");
    bool snakeCase = annotation.peek('snakeCase')?.boolValue ?? false;
    for (var field in (element as ClassElement).fields) {
      if (field.isStatic) continue;
      var dbName = field.name;
      var readOnly = false;
      if (_checkForStanzaField.hasAnnotationOfExact(field)) {
        final reader = ConstantReader(_checkForStanzaField.firstAnnotationOf(field));
        dbName = reader.peek('name')?.stringValue ?? field.name;
        readOnly = reader.peek('readOnly')?.boolValue ?? false;
      }
      if (snakeCase) {
        var rc = ReCase(dbName);
        dbName = rc.snakeCase;
      }
      fieldsBuffer.writeln("final ${field.name} = FieldWrapper('$tableName', '$dbName');");
      fromDbBuffer.writeln("..${field.name} = map['$dbName']");
      if (!readOnly)toDbBuffer.writeln("'$dbName': instance.${field.name},");
      buf.writeln(field.name);
    }
    fieldsBuffer.writeln("}");
    fromDbBuffer.writeln(";}");
    toDbBuffer.writeln("};}");
    tableBuffer.writeAll([fromDbBuffer, toDbBuffer]);
    tableBuffer.writeln("}");
    fileBuffer.writeAll([fieldsBuffer, tableBuffer]);
    return fileBuffer.toString();
  }
}