import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:source_gen/source_gen.dart';
import 'package:recase/recase.dart';

import 'package:stanza/src/annotations/annotations.dart';
import 'package:stanza/src/exception.dart';

final _checkForStanzaField = const TypeChecker.fromRuntime(StanzaField);

class StanzaEntityGenerator extends GeneratorForAnnotation<StanzaEntity> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    
    if (element is! ClassElement) {
      throw('StanzaEntity must only annotate a class.');
    }

    // (element as ClassElement).interfaces.forEach(print);
    
    // // Throw if a to
    // if ((element as ClassElement).constructors.indexWhere((e) => e.name == 'fromDb') == -1) {
    //   var buf = StringBuffer();
    //   buf.writeln('\nThe StanzaEntity class "${element.name}" must have a factory constructor called "fromDb".');
    //   buf.writeln('Here you go: factory ${element.name}.fromDb(Map<String, dynamic> map) => \$${element.name}Entity().fromDb(map);');
    //   throw(QueryException(buf.toString()));
    // };

    var fileBuffer = StringBuffer();
    // var fieldsBuffer = StringBuffer();
    var tableBuffer = StringBuffer();
    
    bool snakeCase = annotation.peek('snakeCase')?.boolValue ?? false;
    var tableName = annotation.peek('name')?.stringValue ;
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

    // var fieldsClassName = "\$${element.name}Fields";
    // fieldsBuffer.writeln("class ${fieldsClassName} {");
    tableBuffer.writeln("class _\$${element.name}Table extends Table<${element.name}> {");
    tableBuffer.writeln("final String \$name = '$tableName';\n");
    // tableBuffer.writeln("final $fieldsClassName fields = $fieldsClassName();\n");
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
      if (_checkForStanzaField.hasAnnotationOfExact(field)) {
        final reader = ConstantReader(_checkForStanzaField.firstAnnotationOf(field));
        dbName = reader.peek('name')?.stringValue ?? field.name;
        readOnly = reader.peek('readOnly')?.boolValue ?? false;
      }
      if (snakeCase) {
        var rc = ReCase(dbName);
        dbName = rc.snakeCase;
      }
      tableBuffer.writeln("final ${field.name} = Field('$tableName', '$dbName');");
      fromDbBuffer.writeln("..${field.name} = map['$dbName']");
      if (!readOnly)toDbBuffer.writeln("'$dbName': instance.${field.name},");
    }
    // fieldsBuffer.writeln("}");
    fromDbBuffer.writeln(";}");
    toDbBuffer.writeln("};}");
    tableBuffer.writeAll(['\n', fromDbBuffer, toDbBuffer]);
    tableBuffer.writeln("}");
    // fileBuffer.writeAll([fieldsBuffer, tableBuffer]);
    fileBuffer.write(tableBuffer);
    return fileBuffer.toString();
  }
}