// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cellar_models.dart';

// **************************************************************************
// EntityGenerator
// **************************************************************************

class $EpisodeTable extends TableDescriptor<Episode> {
  @override
  String get tableName => 'episodes';

  final id = const StringColumn('id', 'episodes');
  final content = const StringColumn('content', 'episodes');
  final type = const StringColumn('type', 'episodes');
  final importance = const DoubleColumn('importance', 'episodes');
  final consolidated = const BoolColumn('consolidated', 'episodes');
  final createdAt = const DateTimeColumn('created_at', 'episodes');
  final updatedAt = const DateTimeColumn('updated_at', 'episodes');

  @override
  List<Column> get columns =>
      [id, content, type, importance, consolidated, createdAt, updatedAt];

  @override
  Column get primaryKey => id;

  @override
  Episode fromRow(Map<String, dynamic> row) => Episode(
        id: row['id'] as String,
        content: row['content'] as String,
        type: row['type'] as String,
        importance: row['importance'] as double,
        consolidated: row['consolidated'] as bool,
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'episodes',
        columns: [
          SchemaColumn(
              name: 'id',
              type: ColumnType('text'),
              dartTypeName: 'String',
              nullable: false,
              isPrimaryKey: true),
          SchemaColumn(
              name: 'content',
              type: ColumnType('text'),
              dartTypeName: 'String',
              nullable: false),
          SchemaColumn(
              name: 'type',
              type: ColumnType('text'),
              dartTypeName: 'String',
              nullable: false),
          SchemaColumn(
              name: 'importance',
              type: ColumnType('double precision'),
              dartTypeName: 'double',
              nullable: false),
          SchemaColumn(
              name: 'consolidated',
              type: ColumnType('boolean'),
              dartTypeName: 'bool',
              nullable: false),
          SchemaColumn(
              name: 'created_at',
              type: ColumnType('timestamptz'),
              dartTypeName: 'DateTime',
              nullable: false),
          SchemaColumn(
              name: 'updated_at',
              type: ColumnType('timestamptz'),
              dartTypeName: 'DateTime',
              nullable: false),
        ],
        constraints: [
          SchemaConstraint(
              name: 'episodes_pkey',
              kind: ConstraintKind.primaryKey,
              columns: ['id']),
        ],
      );
}

class EpisodeInsert {
  final String id;
  final String content;
  final String type;
  final double importance;
  final bool consolidated;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EpisodeInsert({
    required this.id,
    required this.content,
    required this.type,
    required this.importance,
    required this.consolidated,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toRow() => {
        'id': id,
        'content': content,
        'type': type,
        'importance': importance,
        'consolidated': consolidated,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class EpisodeUpdate {
  final String? content;
  final String? type;
  final double? importance;
  final bool? consolidated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EpisodeUpdate({
    this.content,
    this.type,
    this.importance,
    this.consolidated,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toRow() => {
        if (content != null) 'content': content,
        if (type != null) 'type': type,
        if (importance != null) 'importance': importance,
        if (consolidated != null) 'consolidated': consolidated,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

extension EpisodeCopyWith on Episode {
  Episode copyWith({
    String? id,
    String? content,
    String? type,
    double? importance,
    bool? consolidated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Episode(
        id: id ?? this.id,
        content: content ?? this.content,
        type: type ?? this.type,
        importance: importance ?? this.importance,
        consolidated: consolidated ?? this.consolidated,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class $SettingTable extends TableDescriptor<Setting> {
  @override
  String get tableName => 'app_settings';

  final id = const StringColumn('id', 'app_settings');
  final key = const StringColumn('key', 'app_settings');
  final value = const StringColumn('value', 'app_settings');
  final createdAt = const DateTimeColumn('created_at', 'app_settings');
  final updatedAt = const DateTimeColumn('updated_at', 'app_settings');

  @override
  List<Column> get columns => [id, key, value, createdAt, updatedAt];

  @override
  Column get primaryKey => id;

  @override
  Setting fromRow(Map<String, dynamic> row) => Setting(
        id: row['id'] as String,
        key: row['key'] as String,
        value: row['value'] as String?,
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'app_settings',
        columns: [
          SchemaColumn(
              name: 'id',
              type: ColumnType('text'),
              dartTypeName: 'String',
              nullable: false,
              isPrimaryKey: true),
          SchemaColumn(
              name: 'key',
              type: ColumnType('text'),
              dartTypeName: 'String',
              nullable: false,
              isUnique: true),
          SchemaColumn(
              name: 'value', type: ColumnType('text'), dartTypeName: 'String'),
          SchemaColumn(
              name: 'created_at',
              type: ColumnType('timestamptz'),
              dartTypeName: 'DateTime',
              nullable: false),
          SchemaColumn(
              name: 'updated_at',
              type: ColumnType('timestamptz'),
              dartTypeName: 'DateTime',
              nullable: false),
        ],
        constraints: [
          SchemaConstraint(
              name: 'app_settings_pkey',
              kind: ConstraintKind.primaryKey,
              columns: ['id']),
          SchemaConstraint(
              name: 'app_settings_key_key',
              kind: ConstraintKind.unique,
              columns: ['key']),
        ],
      );
}

class SettingInsert {
  final String id;
  final String key;
  final String? value;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SettingInsert({
    required this.id,
    required this.key,
    this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toRow() => {
        'id': id,
        'key': key,
        if (value != null) 'value': value,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class SettingUpdate {
  final String? key;
  final String? value;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SettingUpdate({
    this.key,
    this.value,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toRow() => {
        if (key != null) 'key': key,
        if (value != null) 'value': value,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

extension SettingCopyWith on Setting {
  Setting copyWith({
    String? id,
    String? key,
    String? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Setting(
        id: id ?? this.id,
        key: key ?? this.key,
        value: value ?? this.value,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
