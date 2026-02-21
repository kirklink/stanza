import 'column.dart';
import 'expression.dart';
import 'fts.dart';
import 'order.dart';
import 'parameter.dart';
import 'query.dart';
import 'table.dart';

/// A type-safe SELECT query builder.
///
/// ```dart
/// final query = SelectQuery(userTable)
///     .where((t) => t.email.like('%@example.com') & t.active.isTrue())
///     .orderBy((t) => t.createdAt.desc())
///     .limit(10);
/// ```
class SelectQuery<T, D extends TableDescriptor<T>> extends Query<T, D> {
  final List<Expression> _wheres = [];
  final List<OrderExpression> _orders = [];
  final List<_Join> _joins = [];
  final List<_RawJoin> _rawJoins = [];
  final List<Expression> _havingConditions = [];
  final List<AggregateExpression> _extraSelects = [];
  final List<_RawFragment> _rawSelectFragments = [];
  final List<_RawFragment> _rawOrderFragments = [];
  int? _limit;
  int? _offset;
  bool _distinct = false;
  List<Column>? _selectColumns;
  List<Column>? _groupByColumns;

  SelectQuery(super.table);

  /// Adds a WHERE condition. Multiple calls are combined with AND.
  SelectQuery<T, D> where(Expression Function(D t) predicate) {
    _wheres.add(predicate(table));
    return this;
  }

  /// Adds an ORDER BY clause.
  SelectQuery<T, D> orderBy(OrderExpression Function(D t) order) {
    _orders.add(order(table));
    return this;
  }

  /// Limits the number of rows returned.
  SelectQuery<T, D> limit(int n) {
    _limit = n;
    return this;
  }

  /// Skips the first [n] rows.
  SelectQuery<T, D> offset(int n) {
    _offset = n;
    return this;
  }

  /// Makes the query SELECT DISTINCT.
  SelectQuery<T, D> distinct() {
    _distinct = true;
    return this;
  }

  /// Selects specific columns instead of `*`.
  SelectQuery<T, D> selectOnly(List<Column> Function(D t) columns) {
    _selectColumns = columns(table);
    return this;
  }

  /// Adds an aggregate expression to the SELECT clause.
  ///
  /// ```dart
  /// query.selectExpression(posts.id.count().as('post_count'));
  /// ```
  SelectQuery<T, D> selectExpression(AggregateExpression agg) {
    _extraSelects.add(agg);
    return this;
  }

  /// Groups results by the specified columns.
  ///
  /// ```dart
  /// query.groupBy((t) => [t.authorId]);
  /// ```
  SelectQuery<T, D> groupBy(List<Column> Function(D t) columns) {
    _groupByColumns = columns(table);
    return this;
  }

  /// Adds a HAVING condition on grouped results. Multiple calls are ANDed.
  ///
  /// ```dart
  /// query.having((t) => t.id.count().greaterThan(5));
  /// ```
  SelectQuery<T, D> having(Expression Function(D t) predicate) {
    _havingConditions.add(predicate(table));
    return this;
  }

  // -- Full-text search projections --

  /// Adds `ts_rank(...)` to SELECT and optionally ORDER BY rank DESC.
  ///
  /// ```dart
  /// query
  ///   .where((t) => t.body.fullTextMatches('optimization'))
  ///   .selectRank((t) => t.body, 'optimization');
  /// ```
  SelectQuery<T, D> selectRank(
    StringColumn Function(D t) column,
    String query, {
    String alias = 'rank',
    FtsConfig config = FtsConfig.english,
    FtsQueryType queryType = FtsQueryType.plain,
    bool orderByRank = true,
  }) {
    final col = column(table);
    final tsvec = "to_tsvector('${config.value}', ${col.qualified})";
    final tsq = "${queryType.functionName}('${config.value}', :q)";
    _rawSelectFragments.add(_RawFragment(
      'ts_rank($tsvec, $tsq) AS $alias',
      {'q': query},
    ));
    if (orderByRank) {
      _rawOrderFragments.add(_RawFragment(
        'ts_rank($tsvec, $tsq) DESC',
        {'q': query},
      ));
    }
    return this;
  }

  /// Adds `ts_headline(...)` to SELECT for highlighted search results.
  SelectQuery<T, D> selectHeadline(
    StringColumn Function(D t) column,
    String query, {
    String alias = 'headline',
    FtsConfig config = FtsConfig.english,
    FtsQueryType queryType = FtsQueryType.plain,
    String? options,
  }) {
    final col = column(table);
    final buf = StringBuffer(
      "ts_headline('${config.value}', ${col.qualified}, "
      "${queryType.functionName}('${config.value}', :q)",
    );
    if (options != null) {
      buf.write(", '$options'");
    }
    buf.write(') AS $alias');
    _rawSelectFragments.add(_RawFragment(buf.toString(), {'q': query}));
    return this;
  }

  /// Adds `similarity(column, @text)` to SELECT and optionally ORDER BY DESC.
  SelectQuery<T, D> selectSimilarity(
    StringColumn Function(D t) column,
    String text, {
    String alias = 'similarity_score',
    bool orderBySimilarity = true,
  }) {
    final col = column(table);
    _rawSelectFragments.add(_RawFragment(
      'similarity(${col.qualified}, :t) AS $alias',
      {'t': text},
    ));
    if (orderBySimilarity) {
      _rawOrderFragments.add(_RawFragment(
        'similarity(${col.qualified}, :t) DESC',
        {'t': text},
      ));
    }
    return this;
  }

  /// Adds `column <-> @text` to ORDER BY for GiST-friendly trigram distance.
  SelectQuery<T, D> orderByDistance(
    StringColumn Function(D t) column,
    String text,
  ) {
    final col = column(table);
    _rawOrderFragments.add(_RawFragment(
      '${col.qualified} <-> :t',
      {'t': text},
    ));
    return this;
  }

  // -- SQLite FTS5 projections --

  /// Joins an FTS5 virtual table and adds a MATCH WHERE condition.
  ///
  /// ```dart
  /// query.fts5Join('posts_fts', (t) => t.id, 'database optimization');
  /// ```
  SelectQuery<T, D> fts5Join(
    String ftsTableName,
    Column Function(D t) sourceIdColumn,
    String query,
  ) {
    final col = sourceIdColumn(table);
    _rawJoins.add(_RawJoin(
      'JOIN',
      ftsTableName,
      '${col.qualified} = $ftsTableName.rowid',
    ));
    _wheres.add(Fts5Match(ftsTableName, query));
    return this;
  }

  /// Joins an FTS5 virtual table using SQLite's implicit `rowid`.
  ///
  /// Use this for tables with TEXT primary keys where the FTS5 index
  /// uses `contentRowid: 'rowid'` (the default). For tables with
  /// `INTEGER PRIMARY KEY` columns, [fts5Join] also works.
  ///
  /// ```dart
  /// query.fts5JoinOnRowid('articles_fts', 'search term');
  /// // → JOIN articles_fts ON articles.rowid = articles_fts.rowid
  /// //   WHERE articles_fts MATCH :p0
  /// ```
  SelectQuery<T, D> fts5JoinOnRowid(
    String ftsTableName,
    String query,
  ) {
    _rawJoins.add(_RawJoin(
      'JOIN',
      ftsTableName,
      '${table.tableName}.rowid = $ftsTableName.rowid',
    ));
    _wheres.add(Fts5Match(ftsTableName, query));
    return this;
  }

  /// Adds `bm25(fts_table)` to SELECT and optionally ORDER BY rank.
  ///
  /// ```dart
  /// query.selectFts5Rank('posts_fts', weights: [10.0, 1.0]);
  /// ```
  SelectQuery<T, D> selectFts5Rank(
    String ftsTableName, {
    String alias = 'rank',
    List<double>? weights,
    bool orderByRank = true,
  }) {
    final weightArgs = weights != null ? ', ${weights.join(', ')}' : '';
    final fn = 'bm25($ftsTableName$weightArgs)';
    _rawSelectFragments.add(_RawFragment('$fn AS $alias', const {}));
    if (orderByRank) {
      _rawOrderFragments.add(_RawFragment(fn, const {}));
    }
    return this;
  }

  /// Adds `highlight(fts_table, col_index, open, close)` to SELECT.
  ///
  /// ```dart
  /// query.selectFts5Highlight('posts_fts', 1,
  ///     open: '<mark>', close: '</mark>');
  /// ```
  SelectQuery<T, D> selectFts5Highlight(
    String ftsTableName,
    int columnIndex, {
    String open = '<b>',
    String close = '</b>',
    String alias = 'headline',
  }) {
    _rawSelectFragments.add(_RawFragment(
      'highlight($ftsTableName, $columnIndex, :open, :close) AS $alias',
      {'open': open, 'close': close},
    ));
    return this;
  }

  /// Adds `snippet(fts_table, col_index, open, close, ellipsis, tokens)` to SELECT.
  ///
  /// ```dart
  /// query.selectFts5Snippet('posts_fts', 1, tokens: 32);
  /// ```
  SelectQuery<T, D> selectFts5Snippet(
    String ftsTableName,
    int columnIndex, {
    String open = '<b>',
    String close = '</b>',
    String ellipsis = '...',
    int tokens = 64,
    String alias = 'snippet',
  }) {
    _rawSelectFragments.add(_RawFragment(
      'snippet($ftsTableName, $columnIndex, :open, :close, :ellipsis, $tokens) AS $alias',
      {'open': open, 'close': close, 'ellipsis': ellipsis},
    ));
    return this;
  }

  /// Adds `bm25(fts_table)` to ORDER BY without adding it to SELECT.
  SelectQuery<T, D> orderByFts5Rank(
    String ftsTableName, {
    List<double>? weights,
  }) {
    final weightArgs = weights != null ? ', ${weights.join(', ')}' : '';
    _rawOrderFragments.add(
      _RawFragment('bm25($ftsTableName$weightArgs)', const {}),
    );
    return this;
  }

  /// Adds an INNER JOIN.
  SelectQuery<T, D> innerJoin<J, JD extends TableDescriptor<J>>(
    JD joinTable,
    Expression Function(D t, JD j) on,
  ) {
    _joins.add(_Join('INNER JOIN', joinTable.tableName, on(table, joinTable)));
    return this;
  }

  /// Adds a LEFT JOIN.
  SelectQuery<T, D> leftJoin<J, JD extends TableDescriptor<J>>(
    JD joinTable,
    Expression Function(D t, JD j) on,
  ) {
    _joins.add(_Join('LEFT JOIN', joinTable.tableName, on(table, joinTable)));
    return this;
  }

  /// Adds a RIGHT JOIN.
  SelectQuery<T, D> rightJoin<J, JD extends TableDescriptor<J>>(
    JD joinTable,
    Expression Function(D t, JD j) on,
  ) {
    _joins.add(_Join('RIGHT JOIN', joinTable.tableName, on(table, joinTable)));
    return this;
  }

  /// Generates the full SELECT SQL statement.
  ///
  /// Renders clauses in order: SELECT, FROM, JOIN, WHERE, GROUP BY,
  /// HAVING, ORDER BY, LIMIT, OFFSET.
  @override
  String toSql(ParameterCollector params) {
    final buf = StringBuffer();

    // SELECT
    buf.write('SELECT ');
    if (_distinct) buf.write('DISTINCT ');
    if (_selectColumns != null && _selectColumns!.isNotEmpty) {
      buf.write(_selectColumns!.map((c) => c.qualified).join(', '));
    } else {
      buf.write('${table.tableName}.*');
    }

    // Extra aggregate/expression projections
    for (final agg in _extraSelects) {
      buf.write(', ${agg.toSelectSql()}');
    }

    // Raw select fragments (FTS rank, headline, similarity)
    for (final frag in _rawSelectFragments) {
      buf.write(', ${frag.render(params)}');
    }

    // FROM
    buf.write(' FROM ${table.tableName}');

    // JOINs
    for (final join in _joins) {
      buf.write(' ${join.type} ${join.tableName} ON ${join.on.toSql(params)}');
    }

    // Raw JOINs (FTS5 virtual tables, etc.)
    for (final join in _rawJoins) {
      buf.write(' ${join.type} ${join.tableName} ON ${join.onClause}');
    }

    // WHERE
    if (_wheres.isNotEmpty) {
      buf.write(' WHERE ');
      if (_wheres.length == 1) {
        buf.write(_wheres.first.toSql(params));
      } else {
        final combined =
            _wheres.reduce((a, b) => And(a, b));
        buf.write(combined.toSql(params));
      }
    }

    // GROUP BY
    if (_groupByColumns != null && _groupByColumns!.isNotEmpty) {
      buf.write(' GROUP BY ');
      buf.write(_groupByColumns!.map((c) => c.qualified).join(', '));
    }

    // HAVING
    if (_havingConditions.isNotEmpty) {
      buf.write(' HAVING ');
      if (_havingConditions.length == 1) {
        buf.write(_havingConditions.first.toSql(params));
      } else {
        final combined =
            _havingConditions.reduce((a, b) => And(a, b));
        buf.write(combined.toSql(params));
      }
    }

    // ORDER BY
    final orderParts = <String>[
      ..._orders.map((o) => o.toSql()),
      ..._rawOrderFragments.map((f) => f.render(params)),
    ];
    if (orderParts.isNotEmpty) {
      buf.write(' ORDER BY ');
      buf.write(orderParts.join(', '));
    }

    // LIMIT
    if (_limit != null) {
      buf.write(' LIMIT $_limit');
    }

    // OFFSET
    if (_offset != null) {
      buf.write(' OFFSET $_offset');
    }

    return buf.toString();
  }
}

class _Join {
  final String type;
  final String tableName;
  final Expression on;

  _Join(this.type, this.tableName, this.on);
}

class _RawJoin {
  final String type;
  final String tableName;
  final String onClause;

  _RawJoin(this.type, this.tableName, this.onClause);
}

/// A raw SQL fragment with named placeholders that get resolved to `@pN`.
class _RawFragment {
  final String template;
  final Map<String, Object?> values;

  _RawFragment(this.template, this.values);

  String render(ParameterCollector params) {
    var result = template;
    for (final entry in values.entries) {
      final placeholder = params.add(entry.value);
      result = result.replaceAll(':${entry.key}', placeholder);
    }
    return result;
  }
}
