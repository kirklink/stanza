import 'package:cellar/cellar.dart';
import 'package:stanza/stanza.dart';
import 'package:stanza_example/src/cellar_models.cellar.dart';
import 'package:stanza_example/src/cellar_models.dart';
import 'package:test/test.dart';

void main() {
  late $EpisodeTable episodes;
  late $SettingTable settings;

  setUp(() {
    episodes = $EpisodeTable();
    settings = $SettingTable();
  });

  group('Episode \$episodeCollection', () {
    test('collection name matches table name', () {
      expect($episodeCollection.name, 'episodes');
    });

    test('system fields (id, created_at, updated_at) are excluded', () {
      final fieldNames = $episodeCollection.fields.map((f) => f.name).toList();
      expect(fieldNames, isNot(contains('id')));
      expect(fieldNames, isNot(contains('created_at')));
      expect(fieldNames, isNot(contains('updated_at')));
    });

    test('user fields are included with correct types', () {
      final fieldMap = {
        for (final f in $episodeCollection.fields) f.name: f,
      };

      expect(fieldMap['content']!.type, CellarFieldType.text);
      expect(fieldMap['type']!.type, CellarFieldType.text);
      expect(fieldMap['importance']!.type, CellarFieldType.real);
      expect(fieldMap['consolidated']!.type, CellarFieldType.bool);
    });

    test('fts annotation is propagated for text fields', () {
      final fieldMap = {
        for (final f in $episodeCollection.fields) f.name: f,
      };

      expect(fieldMap['content']!.fts, true);
      expect(fieldMap['type']!.fts, false);
      expect(fieldMap['importance']!.fts, false);
    });

    test('non-nullable fields have nullable: false', () {
      for (final f in $episodeCollection.fields) {
        expect(f.nullable, isFalse, reason: '${f.name} should not be nullable');
      }
    });

    test('no indexes when no unique fields', () {
      expect($episodeCollection.indexes, isEmpty);
    });

    test('collection is usable with Cellar.memory()', () {
      final cellar = Cellar.memory(collections: [$episodeCollection]);
      expect(cellar.schema('episodes'), isNotNull);
      cellar.close();
    });
  });

  group('Setting \$settingCollection', () {
    test('custom collection name from @StanzaEntity(name:)', () {
      expect($settingCollection.name, 'app_settings');
    });

    test('system fields excluded, user fields included', () {
      final fieldNames = $settingCollection.fields.map((f) => f.name).toList();
      expect(fieldNames, ['key', 'value']);
    });

    test('nullable field is marked', () {
      final fieldMap = {
        for (final f in $settingCollection.fields) f.name: f,
      };

      expect(fieldMap['key']!.nullable, isFalse);
      expect(fieldMap['value']!.nullable, isTrue);
    });

    test('unique constraint generates indexes', () {
      expect($settingCollection.indexes, hasLength(1));
      expect($settingCollection.indexes[0].fields, ['key']);
    });
  });

  group('generated table descriptor (Cellar entity)', () {
    test('table name matches collection name', () {
      expect(episodes.tableName, 'episodes');
      expect(settings.tableName, 'app_settings');
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
