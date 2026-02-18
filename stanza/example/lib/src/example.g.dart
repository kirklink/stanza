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
