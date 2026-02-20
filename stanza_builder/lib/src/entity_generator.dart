import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';
import 'package:stanza/annotations.dart';

import 'type_mapping.dart';

const _fieldChecker =
    TypeChecker.fromUrl('package:stanza/src/annotations.dart#Field');
const _pkChecker =
    TypeChecker.fromUrl('package:stanza/src/annotations.dart#PrimaryKey');
const _refChecker =
    TypeChecker.fromUrl('package:stanza/src/annotations.dart#References');

/// Generates table descriptors, companions, and mappers from `@Entity` classes.
class EntityGenerator extends GeneratorForAnnotation<Entity> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@Entity can only be applied to classes.',
        element: element,
      );
    }

    final classEl = element;
    final className = classEl.name!;
    final entityAnnotation = _readEntityAnnotation(annotation);
    final fields = _resolveFields(classEl);

    if (fields.isEmpty) {
      throw InvalidGenerationSourceError(
        '@Entity class $className has no valid fields.',
        element: element,
      );
    }

    final pk = fields.where((f) => f.isPrimaryKey).toList();
    if (pk.isEmpty) {
      throw InvalidGenerationSourceError(
        '@Entity class $className must have exactly one @PrimaryKey field.',
        element: element,
      );
    }
    if (pk.length > 1) {
      throw InvalidGenerationSourceError(
        '@Entity class $className has ${pk.length} @PrimaryKey fields. Only one is allowed.',
        element: element,
      );
    }

    final tableName =
        entityAnnotation.name ?? '${ReCase(className).snakeCase}s';

    final buf = StringBuffer();
    _writeTableDescriptor(buf, className, tableName, fields);
    _writeInsertCompanion(buf, className, fields);
    _writeUpdateCompanion(buf, className, fields);
    _writeCopyWith(buf, className, fields);
    return buf.toString();
  }

  // -- Annotation reading --

  _EntityAnnotation _readEntityAnnotation(ConstantReader reader) {
    return _EntityAnnotation(
      name: reader.read('name').isNull
          ? null
          : reader.read('name').stringValue,
    );
  }

  // -- Field resolution --

  List<_ResolvedField> _resolveFields(ClassElement classEl) {
    final fields = <_ResolvedField>[];

    for (final field in classEl.fields) {
      // Skip static fields and compiler-generated fields (getters for constructors, etc.)
      if (field.isStatic) continue;
      if (field.getter != null && !field.getter!.hasImplicitReturnType) {
        // Explicit getter without a backing field — skip
        if (!field.isFinal && field.setter == null) continue;
      }

      // Check for @Field(ignore: true)
      final fieldAnnotation = _readFieldAnnotation(field);
      if (fieldAnnotation?.ignore == true) continue;

      // Check for @PrimaryKey
      final pkAnnotation = _readPrimaryKeyAnnotation(field);

      // Check for @References
      final refAnnotation = _readReferencesAnnotation(field);

      final dartTypeName = _baseDartType(field.type);
      final isNullable =
          field.type.nullabilitySuffix == NullabilitySuffix.question;

      final fieldName = field.name!;
      final columnName = fieldAnnotation?.name ?? ReCase(fieldName).snakeCase;

      fields.add(_ResolvedField(
        dartName: fieldName,
        dartType: dartTypeName,
        columnName: columnName,
        isNullable: isNullable,
        isPrimaryKey: pkAnnotation != null,
        autoIncrement: pkAnnotation?.autoIncrement ?? false,
        isUnique: fieldAnnotation?.unique ?? false,
        defaultValue: fieldAnnotation?.defaultValue,
        postgresType: fieldAnnotation?.type,
        length: fieldAnnotation?.length,
        references: refAnnotation,
      ));
    }

    return fields;
  }

  _FieldAnnotation? _readFieldAnnotation(FieldElement field) {
    final annotation = _fieldChecker.firstAnnotationOf(field);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    return _FieldAnnotation(
      name: reader.read('name').isNull
          ? null
          : reader.read('name').stringValue,
      length: reader.read('length').isNull
          ? null
          : reader.read('length').intValue,
      unique: reader.read('unique').boolValue,
      defaultValue: reader.read('defaultValue').isNull
          ? null
          : reader.read('defaultValue').stringValue,
      type: reader.read('type').isNull
          ? null
          : reader.read('type').stringValue,
      ignore: reader.read('ignore').boolValue,
    );
  }

  _PrimaryKeyAnnotation? _readPrimaryKeyAnnotation(FieldElement field) {
    final annotation = _pkChecker.firstAnnotationOf(field);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    return _PrimaryKeyAnnotation(
      autoIncrement: reader.read('autoIncrement').boolValue,
    );
  }

  _ReferencesAnnotation? _readReferencesAnnotation(FieldElement field) {
    final annotation = _refChecker.firstAnnotationOf(field);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    final entityType = reader.read('entity').typeValue;
    final entityName =
        entityType.getDisplayString().replaceAll('?', '');

    return _ReferencesAnnotation(
      entityName: entityName,
      column: reader.read('column').isNull
          ? null
          : reader.read('column').stringValue,
      onDelete: reader.read('onDelete').isNull
          ? null
          : reader.read('onDelete').stringValue,
    );
  }

  String _baseDartType(DartType type) {
    return type.getDisplayString().replaceAll('?', '');
  }

  // -- Code generation --

  void _writeTableDescriptor(
    StringBuffer buf,
    String className,
    String tableName,
    List<_ResolvedField> fields,
  ) {
    final tableClass = '\$${className}Table';
    final pkField = fields.firstWhere((f) => f.isPrimaryKey);

    buf.writeln('class $tableClass extends TableDescriptor<$className> {');
    buf.writeln('  @override');
    buf.writeln("  String get tableName => '$tableName';");
    buf.writeln();

    // Typed column fields
    for (final field in fields) {
      final colClass = columnClassForDartType(field.dartType);
      buf.writeln(
          "  final ${field.dartName} = const $colClass('${field.columnName}', '$tableName');");
    }
    buf.writeln();

    // columns getter
    buf.writeln('  @override');
    buf.writeln(
        '  List<Column> get columns => [${fields.map((f) => f.dartName).join(', ')}];');
    buf.writeln();

    // primaryKey getter
    buf.writeln('  @override');
    buf.writeln('  Column get primaryKey => ${pkField.dartName};');
    buf.writeln();

    // fromRow
    buf.writeln('  @override');
    buf.writeln(
        '  $className fromRow(Map<String, dynamic> row) => $className(');
    for (final field in fields) {
      final cast = _castExpression(field);
      buf.writeln("    ${field.dartName}: $cast,");
    }
    buf.writeln('  );');
    buf.writeln();

    // $schema
    _writeSchema(buf, tableName, fields);

    buf.writeln('}');
    buf.writeln();
  }

  void _writeInsertCompanion(
    StringBuffer buf,
    String className,
    List<_ResolvedField> fields,
  ) {
    final companionName = '${className}Insert';

    // Exclude auto-increment PKs from insert
    final insertFields =
        fields.where((f) => !(f.isPrimaryKey && f.autoIncrement)).toList();

    buf.writeln('class $companionName {');

    // Fields: required if non-nullable and no default, optional otherwise
    for (final field in insertFields) {
      final isOptional = field.isNullable || field.defaultValue != null;
      final type = isOptional ? '${field.dartType}?' : field.dartType;
      buf.writeln('  final $type ${field.dartName};');
    }
    buf.writeln();

    // Constructor
    buf.write('  const $companionName({');
    for (final field in insertFields) {
      final isOptional = field.isNullable || field.defaultValue != null;
      if (isOptional) {
        buf.write('this.${field.dartName}, ');
      } else {
        buf.write('required this.${field.dartName}, ');
      }
    }
    buf.writeln('});');
    buf.writeln();

    // toRow()
    buf.writeln('  Map<String, dynamic> toRow() => {');
    for (final field in insertFields) {
      final isOptional = field.isNullable || field.defaultValue != null;
      if (isOptional) {
        buf.writeln(
            "    if (${field.dartName} != null) '${field.columnName}': ${field.dartName},");
      } else {
        buf.writeln("    '${field.columnName}': ${field.dartName},");
      }
    }
    buf.writeln('  };');

    buf.writeln('}');
    buf.writeln();
  }

  void _writeUpdateCompanion(
    StringBuffer buf,
    String className,
    List<_ResolvedField> fields,
  ) {
    final companionName = '${className}Update';

    // Exclude PKs from update
    final updateFields = fields.where((f) => !f.isPrimaryKey).toList();

    buf.writeln('class $companionName {');

    // All fields are optional in update
    for (final field in updateFields) {
      buf.writeln('  final ${field.dartType}? ${field.dartName};');
    }
    buf.writeln();

    // Constructor
    buf.write('  const $companionName({');
    for (final field in updateFields) {
      buf.write('this.${field.dartName}, ');
    }
    buf.writeln('});');
    buf.writeln();

    // toRow()
    buf.writeln('  Map<String, dynamic> toRow() => {');
    for (final field in updateFields) {
      buf.writeln(
          "    if (${field.dartName} != null) '${field.columnName}': ${field.dartName},");
    }
    buf.writeln('  };');

    buf.writeln('}');
    buf.writeln();
  }

  void _writeCopyWith(
    StringBuffer buf,
    String className,
    List<_ResolvedField> fields,
  ) {
    buf.writeln('extension ${className}CopyWith on $className {');
    buf.write('  $className copyWith({');
    for (final field in fields) {
      buf.write('${field.dartType}? ${field.dartName}, ');
    }
    buf.writeln('}) => $className(');
    for (final field in fields) {
      buf.writeln(
          '    ${field.dartName}: ${field.dartName} ?? this.${field.dartName},');
    }
    buf.writeln('  );');
    buf.writeln('}');
  }

  void _writeSchema(
    StringBuffer buf,
    String tableName,
    List<_ResolvedField> fields,
  ) {
    final pkField = fields.firstWhere((f) => f.isPrimaryKey);

    buf.writeln('  @override');
    buf.writeln('  SchemaTable get \$schema => SchemaTable(');
    buf.writeln("    name: '$tableName',");
    buf.writeln('    columns: [');

    for (final field in fields) {
      final pgType = _pgTypeForField(field);
      final nullable = field.isNullable || (field.isPrimaryKey && field.autoIncrement);
      buf.write("      SchemaColumn(name: '${field.columnName}', ");
      buf.write("type: ColumnType('$pgType')");
      if (!nullable) buf.write(', nullable: false');
      if (field.isPrimaryKey) buf.write(', isPrimaryKey: true');
      if (field.autoIncrement) buf.write(', isSerial: true');
      if (field.isUnique) buf.write(', isUnique: true');
      if (field.defaultValue != null) {
        buf.write(", defaultValue: '${field.defaultValue}'");
      }
      buf.writeln('),');
    }

    buf.writeln('    ],');
    buf.writeln('    constraints: [');

    // Primary key constraint
    buf.writeln("      SchemaConstraint(name: '${tableName}_pkey', "
        'kind: ConstraintKind.primaryKey, '
        "columns: ['${pkField.columnName}']),");

    // Unique constraints
    for (final field in fields) {
      if (field.isUnique) {
        buf.writeln(
            "      SchemaConstraint(name: '${tableName}_${field.columnName}_key', "
            'kind: ConstraintKind.unique, '
            "columns: ['${field.columnName}']),");
      }
    }

    // Foreign key constraints
    for (final field in fields) {
      if (field.references != null) {
        final ref = field.references!;
        final refTable = '${ReCase(ref.entityName).snakeCase}s';
        final refColumn = ref.column ?? 'id';
        buf.write(
            "      SchemaConstraint(name: '${tableName}_${field.columnName}_fkey', "
            'kind: ConstraintKind.foreignKey, '
            "columns: ['${field.columnName}'], "
            "referencedTable: '$refTable', "
            "referencedColumn: '$refColumn'");
        if (ref.onDelete != null) {
          buf.write(", onDelete: '${ref.onDelete}'");
        }
        buf.writeln('),');
      }
    }

    buf.writeln('    ],');
    buf.writeln('  );');
  }

  String _pgTypeForField(_ResolvedField field) {
    if (field.postgresType != null) return field.postgresType!;
    if (field.autoIncrement) return serialTypeForDartType(field.dartType);
    if (field.length != null && field.dartType == 'String') {
      return 'varchar(${field.length})';
    }
    return postgresTypeForDartType(field.dartType);
  }

  String _castExpression(_ResolvedField field) {
    final accessor = "row['${field.columnName}']";
    if (field.isNullable) {
      return '$accessor as ${field.dartType}?';
    }
    return '$accessor as ${field.dartType}';
  }
}

// -- Internal data classes --

class _EntityAnnotation {
  final String? name;
  _EntityAnnotation({this.name});
}

class _FieldAnnotation {
  final String? name;
  final int? length;
  final bool unique;
  final String? defaultValue;
  final String? type;
  final bool ignore;

  _FieldAnnotation({
    this.name,
    this.length,
    this.unique = false,
    this.defaultValue,
    this.type,
    this.ignore = false,
  });
}

class _PrimaryKeyAnnotation {
  final bool autoIncrement;
  _PrimaryKeyAnnotation({this.autoIncrement = true});
}

class _ReferencesAnnotation {
  final String entityName;
  final String? column;
  final String? onDelete;

  _ReferencesAnnotation({
    required this.entityName,
    this.column,
    this.onDelete,
  });
}

class _ResolvedField {
  final String dartName;
  final String dartType;
  final String columnName;
  final bool isNullable;
  final bool isPrimaryKey;
  final bool autoIncrement;
  final bool isUnique;
  final String? defaultValue;
  final String? postgresType;
  final int? length;
  final _ReferencesAnnotation? references;

  _ResolvedField({
    required this.dartName,
    required this.dartType,
    required this.columnName,
    required this.isNullable,
    required this.isPrimaryKey,
    required this.autoIncrement,
    required this.isUnique,
    required this.defaultValue,
    required this.postgresType,
    required this.length,
    required this.references,
  });
}
