import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:source_gen/source_gen.dart';
import 'package:recase/recase.dart';

import 'package:stanza/annotations.dart';
import 'package:stanza_builder/src/stanza_builder_exception.dart';

final _checkForStanzaField = const TypeChecker.fromRuntime(StanzaField);

class StanzaEntityGenerator extends GeneratorForAnnotation<StanzaEntity> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw ('StanzaEntity must only annotate a class.');
    }

    var $table = (element as ClassElement).getField('\$table');
    if ($table == null || !$table.isStatic) {
      var buf = StringBuffer();
      var tableClass = "${element.name}Table";
      buf.writeln(
          '\nThe StanzaEntity class "${element.name}" must have a static field "\$table".');
      buf.writeln(
          'Add this to ${element.name}: static _\$$tableClass \$table = _\$$tableClass();');
      throw StanzaBuilderException(buf.toString());
    }

    var fileBuffer = StringBuffer();
    var tableBuffer = StringBuffer();

    bool snakeCase = annotation.peek('snakeCase')?.boolValue ?? false;
    var tableName = annotation.peek('name')?.stringValue;
    // If table name is not provided, use the entity name
    if (tableName == null) {
      tableName = '${element.name}';
      // If the entity is snake case, apply snake case to the entity name
      if (snakeCase) {
        var rc = ReCase(tableName);
        tableName = rc.snakeCase;
      }
    }
    // Otherwise a table name was provided and should be used

    tableBuffer.writeln(
        "class _\$${element.name}Table extends Table<${element.name}> {");
    tableBuffer.writeln("final String \$name = '$tableName';");
    tableBuffer.writeln("final Type \$type = ${element.name};\n");
    var fromDbBuffer = StringBuffer();
    var toDbBuffer = StringBuffer();
    fromDbBuffer.writeln("${element.name} fromDb(Map<String, dynamic> map) {");
    fromDbBuffer.writeln("return ${element.name}()");
    toDbBuffer.writeln("Map<String, dynamic> toDb(${element.name} instance) {");
    toDbBuffer.writeln("return <String, dynamic>{");
    for (var field in (element as ClassElement).fields) {
      if (field.isStatic) continue;
      var dbName = field.name;
      var readOnly = false;
      var ignore = false;
      if (_checkForStanzaField.hasAnnotationOfExact(field)) {
        final reader =
            ConstantReader(_checkForStanzaField.firstAnnotationOf(field));
        dbName = reader.peek('name')?.stringValue ?? field.name;
        readOnly = reader.peek('readOnly')?.boolValue ?? false;
        ignore = reader.peek('ignore')?.boolValue ?? false;
      }
      if (ignore) {
        continue;
      }
      if (snakeCase) {
        var rc = ReCase(dbName);
        dbName = rc.snakeCase;
      }
      tableBuffer.writeln(
          "Field get ${field.name} => Field('$tableName', '$dbName');");
      fromDbBuffer.writeln(
          "..${field.name} = map['$dbName'] as ${field.type.getDisplayString()}");
      if (!readOnly) toDbBuffer.writeln("'$dbName': instance.${field.name},");
    }
    fromDbBuffer.writeln(";}");
    toDbBuffer.writeln("};}");
    tableBuffer.writeAll(['\n', fromDbBuffer, toDbBuffer]);
    tableBuffer.writeln("}");
    fileBuffer.write(tableBuffer);
    return fileBuffer.toString();
  }
}
