// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example.dart';

// **************************************************************************
// StanzaEntityGenerator
// **************************************************************************

class OwnerEntityException implements Exception {
  final String cause;
  OwnerEntityException(this.cause);
  @override
  String toString() => cause;
}

class _$OwnerTable extends Table<Owner> {
  @override
  final String $name = 'owner';
  @override
  final Type $type = Owner;

  Field get id => Field('owner', 'id');
  Field get name => Field('owner', 'name');

  @override
  Owner fromDb(Map<String, dynamic> map) {
    return Owner()
      ..id = map['id'] as int
      ..name = map['name'] as String;
  }

  @override
  Map<String, dynamic> toDb(Owner instance) {
    return <String, dynamic>{
      'name': instance.name,
    };
  }

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'owner',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
            isUnique: false,
          ),
          SchemaColumn(
            name: 'name',
            type: ColumnType('text'),
            nullable: false,
            isPrimaryKey: false,
            isSerial: false,
            isUnique: true,
          ),
        ],
        constraints: [
          SchemaConstraint(
            name: 'owner_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
          SchemaConstraint(
            name: 'owner_name_key',
            kind: ConstraintKind.unique,
            columns: ['name'],
          ),
        ],
      );
}

class AnimalEntityException implements Exception {
  final String cause;
  AnimalEntityException(this.cause);
  @override
  String toString() => cause;
}

class _$AnimalTable extends Table<Animal> {
  @override
  final String $name = 'mammal';
  @override
  final Type $type = Animal;

  Field get id => Field('mammal', 'id');
  Field get name => Field('mammal', 'name');
  Field get legs => Field('mammal', 'number_of_legs');
  Field get color => Field('mammal', 'color');
  Field get createdAt => Field('mammal', 'created_at');
  Field get ownerId => Field('mammal', 'owner_id');

  @override
  Animal fromDb(Map<String, dynamic> map) {
    return Animal()
      ..id = map['id'] as int
      ..name = map['name'] as String
      ..legs = map['number_of_legs'] as int
      ..color = map['color'] as String
      ..createdAt = map['created_at'] as DateTime
      ..ownerId = map['owner_id'] as int;
  }

  @override
  Map<String, dynamic> toDb(Animal instance) {
    return <String, dynamic>{
      'name': instance.name,
      'number_of_legs': instance.legs,
      'color': instance.color,
      'created_at': instance.createdAt,
      'owner_id': instance.ownerId,
    };
  }

  @override
  SchemaTable get $schema => SchemaTable(
        name: 'mammal',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
            isUnique: false,
          ),
          SchemaColumn(
            name: 'name',
            type: ColumnType('text'),
            nullable: false,
            isPrimaryKey: false,
            isSerial: false,
            isUnique: false,
          ),
          SchemaColumn(
            name: 'number_of_legs',
            type: ColumnType('integer'),
            nullable: false,
            isPrimaryKey: false,
            isSerial: false,
            isUnique: false,
          ),
          SchemaColumn(
            name: 'color',
            type: ColumnType('text'),
            nullable: false,
            isPrimaryKey: false,
            isSerial: false,
            isUnique: false,
          ),
          SchemaColumn(
            name: 'created_at',
            type: ColumnType('timestamptz'),
            nullable: false,
            isPrimaryKey: false,
            isSerial: false,
            isUnique: false,
          ),
          SchemaColumn(
            name: 'owner_id',
            type: ColumnType('integer'),
            nullable: false,
            isPrimaryKey: false,
            isSerial: false,
            isUnique: false,
          ),
        ],
        constraints: [
          SchemaConstraint(
            name: 'mammal_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
          SchemaConstraint(
            name: 'mammal_owner_id_fkey',
            kind: ConstraintKind.foreignKey,
            columns: ['owner_id'],
            referencedTable: 'owner',
            referencedColumn: 'id',
            onDelete: 'CASCADE',
          ),
        ],
      );

  // --- BelongsTo: Owner via ownerId ---

  List<Field> get _ownerJoinFields => [
        Field('owner', 'id')..rename('owner__id'),
        Field('owner', 'name')..rename('owner__name'),
      ];

  /// Inner join to [Owner] via owner_id -> owner.id.
  void innerJoinOwner(SelectQuery q) {
    q.selectFields(_ownerJoinFields);
    q.innerJoin(Owner.$table).on(ownerId, Field('owner', 'id'));
  }

  /// Left join to [Owner] via owner_id -> owner.id.
  void leftJoinOwner(SelectQuery q) {
    q.selectFields(_ownerJoinFields);
    q.leftJoin(Owner.$table).on(ownerId, Field('owner', 'id'));
  }

  /// Extract a [Owner] from a joined row.
  /// Returns null if the joined key column is null (e.g., LEFT JOIN miss).
  Owner? ownerFromRow(Map<String, dynamic> row) {
    if (row['owner__id'] == null) return null;
    return Owner()
      ..id = row['owner__id'] as int
      ..name = row['owner__name'] as String;
  }
}
