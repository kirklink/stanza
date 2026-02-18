import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
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
      throw StanzaBuilderException(
          'StanzaEntity must only annotate a class.');
    }

    final classElement = element;
    final tableField = classElement.getField('\$table');
    if (tableField == null || !tableField.isStatic) {
      final tableClass = '${classElement.name}Table';
      final buf = StringBuffer();
      buf.writeln(
          '\nThe StanzaEntity class "${classElement.name}" must have a static field "\$table".');
      buf.writeln(
          'Add this to ${classElement.name}: static _\$$tableClass \$table = _\$$tableClass();');
      throw StanzaBuilderException(buf.toString());
    }

    final fileBuffer = StringBuffer();
    final tableBuffer = StringBuffer();

    final snakeCase = annotation.peek('snakeCase')?.boolValue ?? false;
    var tableName = annotation.peek('name')?.stringValue;
    final readOnlyEntity = annotation.peek('readOnly')?.boolValue ?? false;

    // If table name is not provided, use the entity name
    if (tableName == null) {
      tableName = classElement.name;
      if (snakeCase) {
        tableName = ReCase(tableName).snakeCase;
      }
    }

    tableBuffer.writeln(
        'class _\$${classElement.name}Table extends Table<${classElement.name}> {');
    tableBuffer.writeln('  @override');
    tableBuffer.writeln("  final String \$name = '$tableName';");
    tableBuffer.writeln('  @override');
    tableBuffer.writeln('  final Type \$type = ${classElement.name};\n');

    final fromDbBuffer = StringBuffer();
    final toDbBuffer = StringBuffer();

    fromDbBuffer.writeln('  @override');
    fromDbBuffer.writeln(
        '  ${classElement.name} fromDb(Map<String, dynamic> map) {');
    fromDbBuffer.writeln('    return ${classElement.name}()');

    toDbBuffer.writeln('  @override');
    toDbBuffer.writeln(
        '  Map<String, dynamic> toDb(${classElement.name} instance) {');
    if (readOnlyEntity) {
      toDbBuffer.writeln(
          '    throw ${classElement.name}EntityException("${classElement.name} is read only.");');
    } else {
      toDbBuffer.writeln('    return <String, dynamic>{');
    }

    for (final field in classElement.fields) {
      if (field.isStatic) continue;

      var dbName = field.name;
      var readOnly = false;
      var ignore = false;

      if (_checkForStanzaField.hasAnnotationOfExact(field)) {
        final reader =
            ConstantReader(_checkForStanzaField.firstAnnotationOf(field)!);
        dbName = reader.peek('name')?.stringValue ?? field.name;
        readOnly = reader.peek('readOnly')?.boolValue ?? false;
        ignore = reader.peek('ignore')?.boolValue ?? false;
      }

      if (ignore) continue;

      if (snakeCase) {
        dbName = ReCase(dbName).snakeCase;
      }

      final typeStr = field.type.getDisplayString();

      tableBuffer.writeln(
          "  Field get ${field.name} => Field('$tableName', '$dbName');");
      fromDbBuffer.writeln(
          "      ..${field.name} = map['$dbName'] as $typeStr");

      if (!readOnly && !readOnlyEntity) {
        toDbBuffer.writeln("      '$dbName': instance.${field.name},");
      }
    }

    fromDbBuffer.writeln('    ;');
    fromDbBuffer.writeln('  }');

    if (readOnlyEntity) {
      toDbBuffer.writeln('  }');
    } else {
      toDbBuffer.writeln('    };');
      toDbBuffer.writeln('  }');
    }

    tableBuffer.writeln();
    tableBuffer.write(fromDbBuffer);
    tableBuffer.writeln();
    tableBuffer.write(toDbBuffer);
    tableBuffer.writeln('}');

    // Generate entity exception class
    final exBuf = StringBuffer();
    exBuf.writeln(
        'class ${classElement.name}EntityException implements Exception {');
    exBuf.writeln('  final String cause;');
    exBuf.writeln('  ${classElement.name}EntityException(this.cause);');
    exBuf.writeln('  @override');
    exBuf.writeln('  String toString() => cause;');
    exBuf.writeln('}');

    fileBuffer.writeln();
    fileBuffer.write(exBuf);
    fileBuffer.writeln();
    fileBuffer.write(tableBuffer);
    return fileBuffer.toString();
  }
}
