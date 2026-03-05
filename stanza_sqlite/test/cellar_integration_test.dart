import 'package:cellar/cellar.dart';
import 'package:stanza/stanza.dart';
import 'package:stanza_sqlite/stanza_sqlite.dart';
import 'package:test/test.dart';

// Entity matching a Cellar collection with system fields (id, created_at, updated_at)
class _Episode {
  final String id;
  final String content;
  final String type;
  final double importance;
  final bool consolidated;
  final DateTime createdAt;
  final DateTime updatedAt;

  _Episode({
    required this.id,
    required this.content,
    required this.type,
    required this.importance,
    required this.consolidated,
    required this.createdAt,
    required this.updatedAt,
  });
}

class _EpisodeTable extends TableDescriptor<_Episode> {
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
  _Episode fromRow(Map<String, dynamic> row) => _Episode(
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

/// Collection constant — mirrors what @StanzaEntity(cellar: true) would generate.
const _episodesCollection = CellarCollection(
  name: 'episodes',
  fields: [
    CellarField.text('content', fts: true),
    CellarField.text('type'),
    CellarField.real('importance'),
    CellarField.bool('consolidated', defaultValue: false),
  ],
);

void main() {
  final episodeTable = _EpisodeTable();

  late Cellar cellar;
  late StanzaSqlite stanza;

  setUp(() {
    cellar = Cellar.memory(collections: [_episodesCollection]);
    stanza = StanzaSqlite.fromDatabase(cellar.database);
  });

  tearDown(() async {
    await stanza.close();
    cellar.close();
  });

  group('Insert via Cellar, query via Stanza', () {
    test('basic SELECT returns Cellar-inserted rows', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'User asked about Dart',
        'type': 'observation',
        'importance': 0.7,
      });
      svc.create({
        'content': 'Agent resolved the issue',
        'type': 'action',
        'importance': 0.5,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable);
      final result = await stanza.execute(query);

      expect(result.entities, hasLength(2));
      final names = result.entities.map((e) => e.content).toList();
      expect(names, containsAll(['User asked about Dart', 'Agent resolved the issue']));
    });

    test('WHERE clause filters Cellar data', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'Important observation',
        'type': 'observation',
        'importance': 0.9,
      });
      svc.create({
        'content': 'Minor note',
        'type': 'observation',
        'importance': 0.2,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable)
          .where((t) => t.importance.greaterThan(0.5));
      final result = await stanza.execute(query);

      expect(result.entities, hasLength(1));
      expect(result.entities.first.content, 'Important observation');
    });

    test('string equality WHERE', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'Observation content',
        'type': 'observation',
        'importance': 0.5,
      });
      svc.create({
        'content': 'Action content',
        'type': 'action',
        'importance': 0.5,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable)
          .where((t) => t.type.equals('action'));
      final result = await stanza.execute(query);

      expect(result.entities, hasLength(1));
      expect(result.entities.first.type, 'action');
    });
  });

  group('Insert via Stanza, read via Cellar', () {
    test('rawExecute INSERT visible to Cellar', () async {
      final now = DateTime.utc(2024, 7, 4, 12, 30, 45);
      await stanza.rawExecute(
        'INSERT INTO episodes (id, content, type, importance, consolidated, created_at, updated_at) '
        'VALUES (:id, :content, :type, :importance, :consolidated, :created_at, :updated_at)',
        parameters: {
          'id': '01ARZ3NDEKTSV4RRFFQ69G5FAV',
          'content': 'Stanza-inserted episode',
          'type': 'note',
          'importance': 0.6,
          'consolidated': false,
          'created_at': now,
          'updated_at': now,
        },
      );

      final svc = cellar.collection('episodes');
      final record = svc.get('01ARZ3NDEKTSV4RRFFQ69G5FAV');
      expect(record['content'], 'Stanza-inserted episode');
      expect(record['type'], 'note');
      expect(record['importance'], 0.6);
      expect(record['consolidated'], false);
    });
  });

  group('Type conversions across both paths', () {
    test('bool round-trip: Cellar true → Stanza true', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'Consolidated episode',
        'type': 'observation',
        'importance': 0.8,
        'consolidated': true,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable);
      final result = await stanza.execute(query);
      expect(result.entities.first.consolidated, isTrue);
    });

    test('bool round-trip: Cellar false → Stanza false', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'New episode',
        'type': 'observation',
        'importance': 0.3,
        'consolidated': false,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable);
      final result = await stanza.execute(query);
      expect(result.entities.first.consolidated, isFalse);
    });

    test('DateTime round-trip: Cellar → Stanza preserves value', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'Timestamped',
        'type': 'note',
        'importance': 0.5,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable);
      final result = await stanza.execute(query);
      final episode = result.entities.first;

      // Cellar auto-generates created_at/updated_at — just verify they parse
      expect(episode.createdAt, isA<DateTime>());
      expect(episode.updatedAt, isA<DateTime>());
      expect(episode.createdAt.isUtc, isTrue);
    });

    test('double round-trip preserves precision', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'Precise',
        'type': 'note',
        'importance': 0.123456789,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable);
      final result = await stanza.execute(query);
      expect(result.entities.first.importance, closeTo(0.123456789, 1e-9));
    });

    test('String id from Cellar is accessible via Stanza', () async {
      final svc = cellar.collection('episodes');
      final record = svc.create({
        'content': 'ID test',
        'type': 'note',
        'importance': 0.5,
      });

      final query = SelectQuery<_Episode, _EpisodeTable>(episodeTable);
      final result = await stanza.execute(query);
      expect(result.entities.first.id, record.id);
      expect(result.entities.first.id, isNotEmpty);
    });
  });

  group('Lifecycle', () {
    test('stanza.close() does not dispose Cellar database', () async {
      final svc = cellar.collection('episodes');
      svc.create({
        'content': 'Before close',
        'type': 'note',
        'importance': 0.5,
      });

      await stanza.close();

      // Cellar still works after Stanza closes (ownsDatabase: false)
      final result = svc.list();
      expect(result.items, hasLength(1));
      expect(result.items.first['content'], 'Before close');
    });
  });
}
