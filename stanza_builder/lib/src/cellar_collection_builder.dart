import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'cellar_type_mapping.dart';

const _entityChecker =
    TypeChecker.fromUrl('package:stanza/src/annotations.dart#StanzaEntity');
const _fieldChecker =
    TypeChecker.fromUrl('package:stanza/src/annotations.dart#StanzaField');
const _pkChecker =
    TypeChecker.fromUrl('package:stanza/src/annotations.dart#StanzaKey');

/// Cellar system fields — excluded from the generated CellarCollection.
const _cellarSystemFields = {'id', 'created_at', 'updated_at'};

/// Generates standalone `.cellar.dart` files with `CellarCollection` constants.
///
/// Scans for `@StanzaEntity(cellar: true)` and emits a standalone library file
/// that imports `package:cellar/cellar.dart` automatically. This eliminates the
/// need for consumers to manually import cellar in their model files.
class CellarCollectionBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': ['.cellar.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;

    final library = await resolver.libraryFor(buildStep.inputId);
    final reader = LibraryReader(library);

    final annotated = reader.annotatedWith(_entityChecker).where((a) {
      return a.annotation.read('cellar').boolValue;
    }).toList();

    if (annotated.isEmpty) return;

    final buf = StringBuffer();
    buf.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buf.writeln();
    buf.writeln("import 'package:cellar/cellar.dart';");
    buf.writeln();

    for (final a in annotated) {
      if (a.element is! ClassElement) continue;
      final classEl = a.element as ClassElement;
      _writeCellarCollection(buf, classEl, a.annotation);
    }

    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.cellar.dart'),
      buf.toString(),
    );
  }

  void _writeCellarCollection(
    StringBuffer buf,
    ClassElement classEl,
    ConstantReader annotation,
  ) {
    final className = classEl.name!;
    final tableName = annotation.read('name').isNull
        ? '${ReCase(className).snakeCase}s'
        : annotation.read('name').stringValue;
    final varName = '\$${ReCase(className).camelCase}Collection';

    // Resolve fields, filtering out system fields
    final fields = _resolveUserFields(classEl);

    final uniqueFields = fields.where((f) => f.isUnique).toList();

    buf.writeln('/// Cellar collection schema for `$className`.');
    buf.writeln('///');
    buf.writeln(
        '/// Pass to `Cellar.open(collections: [...])` for table management.');
    buf.writeln('const $varName = CellarCollection(');
    buf.writeln("  name: '$tableName',");
    buf.writeln('  fields: [');

    for (final field in fields) {
      final constructor = cellarFieldConstructor(field.dartType);
      buf.write("    $constructor('${field.columnName}'");
      if (field.fts && field.dartType == 'String') {
        buf.write(', fts: true');
      }
      if (field.isNullable) {
        buf.write(', nullable: true');
      }
      if (field.defaultValue != null) {
        final dv = field.defaultValue!;
        if (_isCellarLiteralDefault(dv, field.dartType)) {
          buf.write(', defaultValue: $dv');
        }
      }
      buf.writeln('),');
    }

    buf.writeln('  ],');

    if (uniqueFields.isNotEmpty) {
      buf.writeln('  indexes: [');
      for (final field in uniqueFields) {
        buf.writeln("    CellarIndex(['${field.columnName}']),");
      }
      buf.writeln('  ],');
    }

    buf.writeln(');');
    buf.writeln();
  }

  List<_CellarField> _resolveUserFields(ClassElement classEl) {
    final fields = <_CellarField>[];

    for (final field in classEl.fields) {
      if (field.isStatic) continue;
      if (field.getter != null && !field.getter!.hasImplicitReturnType) {
        if (!field.isFinal && field.setter == null) continue;
      }

      // Read annotations
      final fieldAnnotation = _readFieldAnnotation(field);
      if (fieldAnnotation?.ignore == true) continue;

      // Skip PKs
      if (_pkChecker.hasAnnotationOf(field)) continue;

      final columnName = fieldAnnotation?.name ?? ReCase(field.name!).snakeCase;

      // Skip Cellar system fields
      if (_cellarSystemFields.contains(columnName)) continue;

      final dartType = _baseDartType(field.type);
      final isNullable =
          field.type.nullabilitySuffix == NullabilitySuffix.question;

      fields.add(_CellarField(
        columnName: columnName,
        dartType: dartType,
        isNullable: isNullable,
        isUnique: fieldAnnotation?.unique ?? false,
        defaultValue: fieldAnnotation?.defaultValue,
        fts: fieldAnnotation?.fts ?? false,
      ));
    }

    return fields;
  }

  _FieldAnnotation? _readFieldAnnotation(FieldElement field) {
    final annotation = _fieldChecker.firstAnnotationOf(field);
    if (annotation == null) return null;

    final reader = ConstantReader(annotation);
    return _FieldAnnotation(
      name:
          reader.read('name').isNull ? null : reader.read('name').stringValue,
      unique: reader.read('unique').boolValue,
      defaultValue: reader.read('defaultValue').isNull
          ? null
          : reader.read('defaultValue').stringValue,
      ignore: reader.read('ignore').boolValue,
      fts: reader.read('fts').boolValue,
    );
  }

  String _baseDartType(DartType type) {
    return type.getDisplayString().replaceAll('?', '');
  }

  bool _isCellarLiteralDefault(String value, String dartType) {
    if (dartType == 'int' || dartType == 'double') {
      return num.tryParse(value) != null;
    }
    if (dartType == 'bool') return value == 'true' || value == 'false';
    if (dartType == 'String' &&
        value.startsWith("'") &&
        value.endsWith("'")) {
      return true;
    }
    return false;
  }
}

class _FieldAnnotation {
  final String? name;
  final bool unique;
  final String? defaultValue;
  final bool ignore;
  final bool fts;

  _FieldAnnotation({
    this.name,
    this.unique = false,
    this.defaultValue,
    this.ignore = false,
    this.fts = false,
  });
}

class _CellarField {
  final String columnName;
  final String dartType;
  final bool isNullable;
  final bool isUnique;
  final String? defaultValue;
  final bool fts;

  _CellarField({
    required this.columnName,
    required this.dartType,
    required this.isNullable,
    required this.isUnique,
    required this.defaultValue,
    required this.fts,
  });
}
