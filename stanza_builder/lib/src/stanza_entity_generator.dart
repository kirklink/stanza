import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:recase/recase.dart';

import 'package:stanza/annotations.dart';
import 'package:stanza_builder/src/stanza_builder_exception.dart';

const _checkForStanzaEntity = TypeChecker.fromUrl(
    'package:stanza/src/annotations.dart#StanzaEntity');

const _checkForStanzaField = TypeChecker.fromUrl(
    'package:stanza/src/annotations.dart#StanzaField');

const _checkForBelongsTo = TypeChecker.fromUrl(
    'package:stanza/src/annotations.dart#BelongsTo');

// ---------------------------------------------------------------------------
// Data classes for resolved entity metadata
// ---------------------------------------------------------------------------

class _ResolvedField {
  final String dartName;
  final String dbName;
  final String typeStr;
  final bool readOnly;
  final bool ignore;

  _ResolvedField({
    required this.dartName,
    required this.dbName,
    required this.typeStr,
    required this.readOnly,
    required this.ignore,
  });
}

class _ResolvedEntity {
  final String className;
  final String tableName;
  final bool snakeCase;
  final bool readOnlyEntity;
  final List<_ResolvedField> fields;

  _ResolvedEntity({
    required this.className,
    required this.tableName,
    required this.snakeCase,
    required this.readOnlyEntity,
    required this.fields,
  });

  List<_ResolvedField> get activeFields =>
      fields.where((f) => !f.ignore).toList();
}

class _BelongsToRelationship {
  final String fieldDartName;
  final String fieldDbName;
  final String relName;
  final String relNameCap;
  final String targetKey;
  final _ResolvedEntity parentEntity;

  _BelongsToRelationship({
    required this.fieldDartName,
    required this.fieldDbName,
    required this.relName,
    required this.relNameCap,
    required this.targetKey,
    required this.parentEntity,
  });
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

class StanzaEntityGenerator extends GeneratorForAnnotation<StanzaEntity> {
  /// Resolve a [ClassElement] annotated with @StanzaEntity into field metadata.
  _ResolvedEntity _resolveEntity(ClassElement classElement) {
    final entityAnnotation =
        _checkForStanzaEntity.firstAnnotationOf(classElement);
    if (entityAnnotation == null) {
      throw StanzaBuilderException(
          'Class "${classElement.name}" referenced via @BelongsTo must be '
          'annotated with @StanzaEntity.');
    }
    final reader = ConstantReader(entityAnnotation);
    final snakeCase = reader.peek('snakeCase')?.boolValue ?? false;
    final readOnlyEntity = reader.peek('readOnly')?.boolValue ?? false;
    var tableName = reader.peek('name')?.stringValue;
    if (tableName == null) {
      tableName = classElement.name;
      if (snakeCase) tableName = ReCase(tableName!).snakeCase;
    }

    final fields = <_ResolvedField>[];
    for (final field in classElement.fields) {
      if (field.isStatic) continue;

      var dbName = field.name!;
      var readOnly = false;
      var ignore = false;

      if (_checkForStanzaField.hasAnnotationOfExact(field)) {
        final fieldReader =
            ConstantReader(_checkForStanzaField.firstAnnotationOf(field)!);
        dbName = fieldReader.peek('name')?.stringValue ?? field.name!;
        readOnly = fieldReader.peek('readOnly')?.boolValue ?? false;
        ignore = fieldReader.peek('ignore')?.boolValue ?? false;
      }

      if (snakeCase) dbName = ReCase(dbName).snakeCase;

      fields.add(_ResolvedField(
        dartName: field.name!,
        dbName: dbName,
        typeStr: field.type.getDisplayString(),
        readOnly: readOnly,
        ignore: ignore,
      ));
    }

    return _ResolvedEntity(
      className: classElement.name!,
      tableName: tableName!,
      snakeCase: snakeCase,
      readOnlyEntity: readOnlyEntity,
      fields: fields,
    );
  }

  /// Derive a relationship name from a FK field name by stripping the 'Id' suffix.
  String _relName(String fieldName) {
    if (fieldName.endsWith('Id')) {
      return fieldName.substring(0, fieldName.length - 2);
    }
    return fieldName;
  }

  /// Detect @BelongsTo annotations on [classElement]'s fields and resolve
  /// the parent entities.
  List<_BelongsToRelationship> _resolveRelationships(
      ClassElement classElement, _ResolvedEntity entity) {
    final relationships = <_BelongsToRelationship>[];
    final parentTypesSeen = <String>{};

    for (final field in classElement.fields) {
      if (field.isStatic) continue;
      if (!_checkForBelongsTo.hasAnnotationOfExact(field)) continue;

      final btObj = _checkForBelongsTo.firstAnnotationOf(field)!;
      final parentType = btObj.getField('parent')!.toTypeValue()!;
      final parentElement = parentType.element as ClassElement;

      // V1 constraint: one BelongsTo per parent type
      if (!parentTypesSeen.add(parentElement.name!)) {
        throw StanzaBuilderException(
            'Multiple @BelongsTo annotations referencing "${parentElement.name}" '
            'on "${classElement.name}". Only one per parent type is supported.');
      }

      final targetKey =
          ConstantReader(btObj).peek('targetKey')?.stringValue ?? 'id';
      final parentEntity = _resolveEntity(parentElement);

      // Validate targetKey exists in parent
      final hasTargetKey =
          parentEntity.activeFields.any((f) => f.dbName == targetKey);
      if (!hasTargetKey) {
        throw StanzaBuilderException(
            '@BelongsTo on "${classElement.name}.${field.name}": '
            'target key "$targetKey" not found in ${parentEntity.className} '
            'table "${parentEntity.tableName}".');
      }

      final relName = _relName(field.name!);
      // Find the resolved FK field for its dbName
      final fkField =
          entity.activeFields.firstWhere((f) => f.dartName == field.name!);

      relationships.add(_BelongsToRelationship(
        fieldDartName: field.name!,
        fieldDbName: fkField.dbName,
        relName: relName,
        relNameCap: relName[0].toUpperCase() + relName.substring(1),
        targetKey: targetKey,
        parentEntity: parentEntity,
      ));
    }

    return relationships;
  }

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

    // Resolve entity and relationships
    final entity = _resolveEntity(classElement);
    final relationships = _resolveRelationships(classElement, entity);

    // --- Generate exception class ---
    final fileBuffer = StringBuffer();
    final exBuf = StringBuffer();
    exBuf.writeln(
        'class ${entity.className}EntityException implements Exception {');
    exBuf.writeln('  final String cause;');
    exBuf.writeln('  ${entity.className}EntityException(this.cause);');
    exBuf.writeln('  @override');
    exBuf.writeln('  String toString() => cause;');
    exBuf.writeln('}');

    // --- Generate table class ---
    final tableBuffer = StringBuffer();
    tableBuffer.writeln(
        'class _\$${entity.className}Table extends Table<${entity.className}> {');
    tableBuffer.writeln('  @override');
    tableBuffer.writeln("  final String \$name = '${entity.tableName}';");
    tableBuffer.writeln('  @override');
    tableBuffer.writeln('  final Type \$type = ${entity.className};\n');

    // Field getters
    for (final field in entity.activeFields) {
      tableBuffer.writeln(
          "  Field get ${field.dartName} => Field('${entity.tableName}', '${field.dbName}');");
    }

    // fromDb
    final fromDbBuffer = StringBuffer();
    fromDbBuffer.writeln('\n  @override');
    fromDbBuffer.writeln(
        '  ${entity.className} fromDb(Map<String, dynamic> map) {');
    fromDbBuffer.writeln('    return ${entity.className}()');
    for (final field in entity.activeFields) {
      fromDbBuffer.writeln(
          "      ..${field.dartName} = map['${field.dbName}'] as ${field.typeStr}");
    }
    fromDbBuffer.writeln('    ;');
    fromDbBuffer.writeln('  }');

    // toDb
    final toDbBuffer = StringBuffer();
    toDbBuffer.writeln('\n  @override');
    toDbBuffer.writeln(
        '  Map<String, dynamic> toDb(${entity.className} instance) {');
    if (entity.readOnlyEntity) {
      toDbBuffer.writeln(
          '    throw ${entity.className}EntityException("${entity.className} is read only.");');
    } else {
      toDbBuffer.writeln('    return <String, dynamic>{');
      for (final field in entity.activeFields) {
        if (!field.readOnly) {
          toDbBuffer
              .writeln("      '${field.dbName}': instance.${field.dartName},");
        }
      }
      toDbBuffer.writeln('    };');
    }
    toDbBuffer.writeln('  }');

    tableBuffer.write(fromDbBuffer);
    tableBuffer.write(toDbBuffer);

    // --- Generate BelongsTo join helpers ---
    for (final rel in relationships) {
      final parent = rel.parentEntity;
      final parentFields = parent.activeFields;

      tableBuffer.writeln();
      tableBuffer.writeln(
          '  // --- BelongsTo: ${parent.className} via ${rel.fieldDartName} ---');

      // Aliased fields list
      tableBuffer.writeln();
      tableBuffer.writeln(
          '  List<Field> get _${rel.relName}JoinFields => [');
      for (final pf in parentFields) {
        tableBuffer.writeln(
            "    Field('${parent.tableName}', '${pf.dbName}')..rename('${parent.tableName}__${pf.dbName}'),");
      }
      tableBuffer.writeln('  ];');

      // innerJoin helper
      tableBuffer.writeln();
      tableBuffer.writeln(
          '  /// Inner join to [${parent.className}] via ${rel.fieldDbName} -> ${parent.tableName}.${rel.targetKey}.');
      tableBuffer
          .writeln('  void innerJoin${rel.relNameCap}(SelectQuery q) {');
      tableBuffer
          .writeln('    q.selectFields(_${rel.relName}JoinFields);');
      tableBuffer.writeln(
          "    q.innerJoin(${parent.className}.\$table).on(${rel.fieldDartName}, Field('${parent.tableName}', '${rel.targetKey}'));");
      tableBuffer.writeln('  }');

      // leftJoin helper
      tableBuffer.writeln();
      tableBuffer.writeln(
          '  /// Left join to [${parent.className}] via ${rel.fieldDbName} -> ${parent.tableName}.${rel.targetKey}.');
      tableBuffer
          .writeln('  void leftJoin${rel.relNameCap}(SelectQuery q) {');
      tableBuffer
          .writeln('    q.selectFields(_${rel.relName}JoinFields);');
      tableBuffer.writeln(
          "    q.leftJoin(${parent.className}.\$table).on(${rel.fieldDartName}, Field('${parent.tableName}', '${rel.targetKey}'));");
      tableBuffer.writeln('  }');

      // fromRow extraction
      tableBuffer.writeln();
      tableBuffer.writeln(
          '  /// Extract a [${parent.className}] from a joined row.');
      tableBuffer.writeln(
          '  /// Returns null if the joined key column is null (e.g., LEFT JOIN miss).');
      tableBuffer.writeln(
          '  ${parent.className}? ${rel.relName}FromRow(Map<String, dynamic> row) {');
      tableBuffer.writeln(
          "    if (row['${parent.tableName}__${rel.targetKey}'] == null) return null;");
      tableBuffer.writeln('    return ${parent.className}()');
      for (final pf in parentFields) {
        tableBuffer.writeln(
            "      ..${pf.dartName} = row['${parent.tableName}__${pf.dbName}'] as ${pf.typeStr}");
      }
      tableBuffer.writeln('    ;');
      tableBuffer.writeln('  }');
    }

    tableBuffer.writeln('}');

    fileBuffer.writeln();
    fileBuffer.write(exBuf);
    fileBuffer.writeln();
    fileBuffer.write(tableBuffer);
    return fileBuffer.toString();
  }
}
