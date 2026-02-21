/// Configuration for an FTS5 full-text search index backed by an external
/// content table.
///
/// ```dart
/// const postsFts = Fts5Index(
///   sourceTable: 'posts',
///   columns: ['title', 'body'],
///   tokenize: 'porter unicode61',
/// );
/// ```
class Fts5Index {
  /// The source table that holds the actual data (e.g. `'posts'`).
  final String sourceTable;

  /// Column names from the source table to include in the FTS index.
  final List<String> columns;

  final String? _tableName;

  /// The column in the source table that maps to the FTS5 `rowid`.
  ///
  /// Defaults to `'rowid'` — SQLite's implicit integer rowid, which exists
  /// on every table regardless of the declared primary key type. This works
  /// universally for both INTEGER PK and TEXT PK tables.
  ///
  /// For `INTEGER PRIMARY KEY` tables, `'rowid'` and the PK column name
  /// (e.g. `'id'`) are interchangeable since INTEGER PKs alias `rowid`.
  final String contentRowid;

  /// Optional FTS5 tokenizer specification (e.g. `'porter unicode61'`).
  final String? tokenize;

  const Fts5Index({
    required this.sourceTable,
    required this.columns,
    String? tableName,
    this.contentRowid = 'rowid',
    this.tokenize,
  }) : _tableName = tableName;

  /// The FTS5 virtual table name. Defaults to `${sourceTable}_fts`.
  String get tableName => _tableName ?? '${sourceTable}_fts';
}
