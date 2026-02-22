import 'package:cellar/cellar.dart';
import 'package:stanza/stanza.dart';
import 'package:stanza_example/src/cellar_models.dart';
import 'package:test/test.dart';

void main() {
  late $EpisodeTable episodes;
  late $SettingTable settings;

  setUp(() {
    episodes = $EpisodeTable();
    settings = $SettingTable();
  });

  group('Episode \$cellarSchema', () {
    test('collection name matches table name', () {
      final schema = episodes.$cellarSchema;
      expect(schema['name'], 'episodes');
    });

    test('system fields (id, created_at, updated_at) are excluded', () {
      final schema = episodes.$cellarSchema;
      final fields = schema['fields'] as List;
      final fieldNames = fields.map((f) => (f as Map)['name']).toList();
      expect(fieldNames, isNot(contains('id')));
      expect(fieldNames, isNot(contains('created_at')));
      expect(fieldNames, isNot(contains('updated_at')));
    });

    test('user fields are included with correct types', () {
      final schema = episodes.$cellarSchema;
      final fields = schema['fields'] as List;
      final fieldMap = {
        for (final f in fields) (f as Map)['name']: f,
      };

      expect(fieldMap['content']!['type'], 'text');
      expect(fieldMap['type']!['type'], 'text');
      expect(fieldMap['importance']!['type'], 'real');
      expect(fieldMap['consolidated']!['type'], 'bool');
    });

    test('fts annotation is propagated for text fields', () {
      final schema = episodes.$cellarSchema;
      final fields = schema['fields'] as List;
      final fieldMap = {
        for (final f in fields) (f as Map)['name']: f,
      };

      expect(fieldMap['content']!['fts'], true);
      // Non-FTS fields should not have 'fts' key
      expect(fieldMap['type']!.containsKey('fts'), isFalse);
      expect(fieldMap['importance']!.containsKey('fts'), isFalse);
    });

    test('non-nullable fields omit nullable key', () {
      final schema = episodes.$cellarSchema;
      final fields = schema['fields'] as List;
      for (final f in fields) {
        expect((f as Map).containsKey('nullable'), isFalse,
            reason: '${f['name']} should not have nullable key');
      }
    });

    test('no indexes when no unique fields', () {
      final schema = episodes.$cellarSchema;
      expect(schema.containsKey('indexes'), isFalse);
    });

    test('round-trips through Collection.fromJson', () {
      final collection = Collection.fromJson(episodes.$cellarSchema);
      expect(collection.name, 'episodes');
      expect(collection.fields, hasLength(4));
      expect(collection.fields[0].name, 'content');
      expect(collection.fields[0].type, FieldType.text);
      expect(collection.fields[0].fts, true);
      expect(collection.fields[1].name, 'type');
      expect(collection.fields[1].type, FieldType.text);
      expect(collection.fields[1].fts, false);
      expect(collection.fields[2].name, 'importance');
      expect(collection.fields[2].type, FieldType.real);
      expect(collection.fields[3].name, 'consolidated');
      expect(collection.fields[3].type, FieldType.bool);
      expect(collection.indexes, isEmpty);
    });
  });

  group('Setting \$cellarSchema', () {
    test('custom collection name from @CellarCollection(name:)', () {
      final schema = settings.$cellarSchema;
      expect(schema['name'], 'app_settings');
    });

    test('system fields excluded, user fields included', () {
      final schema = settings.$cellarSchema;
      final fields = schema['fields'] as List;
      final fieldNames = fields.map((f) => (f as Map)['name']).toList();
      expect(fieldNames, ['key', 'value']);
    });

    test('nullable field is marked', () {
      final schema = settings.$cellarSchema;
      final fields = schema['fields'] as List;
      final fieldMap = {
        for (final f in fields) (f as Map)['name']: f,
      };

      expect(fieldMap['key']!.containsKey('nullable'), isFalse);
      expect(fieldMap['value']!['nullable'], true);
    });

    test('unique constraint generates indexes', () {
      final schema = settings.$cellarSchema;
      final indexes = schema['indexes'] as List;
      expect(indexes, hasLength(1));
      final idx = indexes[0] as Map;
      expect(idx['type'], 'unique');
      expect(idx['fields'], ['key']);
    });

    test('round-trips through Collection.fromJson', () {
      final collection = Collection.fromJson(settings.$cellarSchema);
      expect(collection.name, 'app_settings');
      expect(collection.fields, hasLength(2));
      expect(collection.fields[0].name, 'key');
      expect(collection.fields[0].nullable, false);
      expect(collection.fields[1].name, 'value');
      expect(collection.fields[1].nullable, true);
      expect(collection.indexes, hasLength(1));
      expect(collection.indexes[0].fields, ['key']);
    });
  });

  group('generated table descriptor (Cellar entity)', () {
    test('table name is pluralized snake_case', () {
      expect(episodes.tableName, 'episodes');
      expect(settings.tableName, 'settings');
    });

    test('columns include system fields', () {
      final colNames = episodes.columns.map((c) => c.name).toList();
      expect(colNames, contains('id'));
      expect(colNames, contains('created_at'));
      expect(colNames, contains('updated_at'));
    });

    test('primary key is String id', () {
      expect(episodes.primaryKey.name, 'id');
      expect(episodes.id, isA<StringColumn>());
    });

    test('fromRow maps correctly', () {
      final now = DateTime.now();
      final episode = episodes.fromRow({
        'id': '01ARZ3NDEKTSV4RRFFQ69G5FAV',
        'content': 'test content',
        'type': 'observation',
        'importance': 0.8,
        'consolidated': true,
        'created_at': now,
        'updated_at': now,
      });
      expect(episode.id, '01ARZ3NDEKTSV4RRFFQ69G5FAV');
      expect(episode.content, 'test content');
      expect(episode.type, 'observation');
      expect(episode.importance, 0.8);
      expect(episode.consolidated, true);
    });
  });

  group('generated companions (Cellar entity)', () {
    test('insert includes all fields (no auto-increment)', () {
      final now = DateTime.now();
      final insert = EpisodeInsert(
        id: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
        content: 'test',
        type: 'note',
        importance: 0.5,
        consolidated: false,
        createdAt: now,
        updatedAt: now,
      );
      final row = insert.toRow();
      expect(row.containsKey('id'), isTrue);
      expect(row['content'], 'test');
    });

    test('update excludes PK', () {
      final update = EpisodeUpdate(content: 'updated');
      final row = update.toRow();
      expect(row.containsKey('id'), isFalse);
      expect(row['content'], 'updated');
    });

    test('nullable insert field is optional', () {
      final now = DateTime.now();
      final insert = SettingInsert(
        id: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
        key: 'theme',
        createdAt: now,
        updatedAt: now,
      );
      final row = insert.toRow();
      expect(row.containsKey('value'), isFalse);
    });
  });
}
