import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/select/select_clause.dart';
import 'package:stanza/src/select/join_clause.dart';
import 'package:stanza/src/shared/fts_config.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/select/having_clause.dart';
import 'package:stanza/src/select/group_by_clause.dart';
import 'package:stanza/src/select/order_by_clause.dart';
import 'package:stanza/src/select/limit_clause.dart';
import 'package:stanza/src/select/offset_clause.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/value_substitution.dart';

/// Base class for a select query.
///
/// Takes the generated code table from a [StanzaEntity].
class SelectQuery extends Query with WhereClause, HavingClause {
  SelectClause _selectClause = SelectClause();
  List<JoinClause> _joins = [];
  OrderByClause _orderByClause = OrderByClause();
  GroupByClause? _groupByClause;
  LimitClause? _limitClause;
  OffsetClause? _offsetClause;
  bool _distinct = false;

  SelectQuery(super.table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final select = _selectClause.clause;
    final where = whereClauses;
    final limit = _limitClause?.clause;
    final offset = _offsetClause?.clause;
    final group = _groupByClause?.clause;
    final order = _orderByClause.isEmpty ? null : _orderByClause.clause;

    final buf = StringBuffer();
    buf.writeAll(['SELECT ', if (_distinct) 'DISTINCT ', select]);
    buf.writeAll([br, 'FROM ', table.$name]);
    for (final join in _joins) {
      buf.writeAll([br, join.clause]);
    }
    final having = havingClauses;
    if (where != null) buf.writeAll([br, where]);
    if (group != null) buf.writeAll([br, group]);
    if (having != null) buf.writeAll([br, having]);
    if (order != null) buf.writeAll([br, order]);
    if (limit != null) buf.writeAll([br, limit]);
    if (offset != null) buf.writeAll([br, offset]);
    return buf.toString();
  }

  /// Mark this query as SELECT DISTINCT.
  void distinct() {
    _distinct = true;
  }

  /// Select a list of [Field]s from a [StanzaEntity] table.
  void selectFields(List<Field> fields) {
    _selectClause.add(fields);
  }

  /// Select all the [Field]s from a [StanzaEntity] table.
  void selectStar([Table? t]) {
    _selectClause.star(t ?? table);
  }

  /// Add an INNER JOIN to this query.
  JoinClause innerJoin(Table joinTable) {
    final join = JoinClause(JoinType.inner, joinTable);
    _joins.add(join);
    return join;
  }

  /// Add a LEFT JOIN to this query.
  JoinClause leftJoin(Table joinTable) {
    final join = JoinClause(JoinType.left, joinTable);
    _joins.add(join);
    return join;
  }

  /// Add a RIGHT JOIN to this query.
  JoinClause rightJoin(Table joinTable) {
    final join = JoinClause(JoinType.right, joinTable);
    _joins.add(join);
    return join;
  }

  /// Add a CROSS JOIN to this query.
  JoinClause crossJoin(Table joinTable) {
    final join = JoinClause(JoinType.cross, joinTable);
    _joins.add(join);
    return join;
  }

  /// Group a select query by a list of [Field]s.
  void groupBy(List<Field> fields) {
    if (_groupByClause != null) {
      throw StanzaException(
          'Cannot have more than one group by clause in a query.');
    }
    _groupByClause = GroupByClause(fields);
  }

  /// Order a select query by the provided [Field].
  ///
  /// [descending]: can be made true to reverse the sort order.
  /// Multiple orderBy clauses can be added to a select query and they are applied in the
  /// order provided.
  void orderBy(Field field, {bool descending = false}) {
    _orderByClause.add(field, descending: descending);
  }

  /// Limit the number of results returned by a query.
  void limit(int i) {
    if (_limitClause != null) {
      throw StanzaException(
          'Cannot have more than one limit clause in a query.');
    }
    _limitClause = LimitClause(i);
  }

  /// Offset the results returned by a query by this number of rows.
  void offset(int i) {
    if (_offsetClause != null) {
      throw StanzaException(
          'Cannot have more than one offset clause in a query.');
    }
    _offsetClause = OffsetClause(i);
  }

  /// Add a full-text search rank expression to SELECT and optionally ORDER BY.
  ///
  /// Produces `ts_rank(to_tsvector('config', field), tsquery('config', @param)) AS alias`
  /// in the SELECT list, and optionally adds it to ORDER BY DESC.
  ///
  /// [field] is the text column to search.
  /// [query] is the search text (parameterized automatically).
  /// [alias] is the column alias for the rank score (default: 'rank').
  /// [config] specifies the text search dictionary (default: english).
  /// [queryType] specifies the tsquery parser (default: plain).
  /// [orderByRank] if true, adds ORDER BY rank DESC (default: true).
  void selectRank(
    Field field,
    String query, {
    String alias = 'rank',
    FtsConfig config = FtsConfig.english,
    FtsQueryType queryType = FtsQueryType.plain,
    bool orderByRank = true,
  }) {
    final sub = ValueSub(
        '${field.qualifiedName.replaceAll('.', '_')}_rank', query);
    addSubstitution(sub);
    final tsqueryFn = switch (queryType) {
      FtsQueryType.plain => 'plainto_tsquery',
      FtsQueryType.websearch => 'websearch_to_tsquery',
      FtsQueryType.phrase => 'phraseto_tsquery',
    };
    final expr =
        "ts_rank(to_tsvector('${config.value}', ${field.qualifiedName}), "
        "$tsqueryFn('${config.value}', ${sub.token}))";
    _selectClause.addExpression('$expr AS $alias');
    if (orderByRank) {
      _orderByClause.addExpression(expr, descending: true);
    }
  }

  /// Add a full-text search headline expression to SELECT.
  ///
  /// Produces `ts_headline('config', field, tsquery('config', @param), 'options') AS alias`
  /// in the SELECT list. Headlines produce highlighted text snippets.
  ///
  /// [field] is the text column to produce headlines from.
  /// [query] is the search text (parameterized automatically).
  /// [alias] is the column alias for the headline (default: 'headline').
  /// [config] specifies the text search dictionary (default: english).
  /// [queryType] specifies the tsquery parser (default: plain).
  /// [options] is the PostgreSQL headline options string
  ///   (e.g., `'StartSel=<b>, StopSel=</b>, MaxWords=35, MinWords=15'`).
  void selectHeadline(
    Field field,
    String query, {
    String alias = 'headline',
    FtsConfig config = FtsConfig.english,
    FtsQueryType queryType = FtsQueryType.plain,
    String? options,
  }) {
    final sub = ValueSub(
        '${field.qualifiedName.replaceAll('.', '_')}_headline', query);
    addSubstitution(sub);
    final tsqueryFn = switch (queryType) {
      FtsQueryType.plain => 'plainto_tsquery',
      FtsQueryType.websearch => 'websearch_to_tsquery',
      FtsQueryType.phrase => 'phraseto_tsquery',
    };
    final optionsStr = options != null ? ", '$options'" : '';
    final expr =
        "ts_headline('${config.value}', ${field.qualifiedName}, "
        "$tsqueryFn('${config.value}', ${sub.token})$optionsStr)";
    _selectClause.addExpression('$expr AS $alias');
  }

  /// Add a trigram similarity score to SELECT and optionally ORDER BY.
  ///
  /// Produces `similarity(field, @param) AS alias` in the SELECT list,
  /// and optionally adds ORDER BY similarity DESC.
  /// Requires the `pg_trgm` extension to be enabled in PostgreSQL.
  ///
  /// [field] is the text column to compare.
  /// [text] is the comparison text (parameterized automatically).
  /// [alias] is the column alias for the score (default: 'similarity_score').
  /// [orderBySimilarity] if true, adds ORDER BY similarity DESC (default: true).
  void selectSimilarity(
    Field field,
    String text, {
    String alias = 'similarity_score',
    bool orderBySimilarity = true,
  }) {
    final sub = ValueSub(
        '${field.qualifiedName.replaceAll('.', '_')}_sim', text);
    addSubstitution(sub);
    final expr = 'similarity(${field.qualifiedName}, ${sub.token})';
    _selectClause.addExpression('$expr AS $alias');
    if (orderBySimilarity) {
      _orderByClause.addExpression(expr, descending: true);
    }
  }

  /// Order by trigram distance (ascending — most similar first).
  ///
  /// Produces `ORDER BY field <-> @param ASC`.
  /// Uses the trigram distance operator which is GiST-index-friendly.
  /// Requires the `pg_trgm` extension to be enabled in PostgreSQL.
  ///
  /// [field] is the text column to compare.
  /// [text] is the comparison text (parameterized automatically).
  void orderByDistance(Field field, String text) {
    final sub = ValueSub(
        '${field.qualifiedName.replaceAll('.', '_')}_dist', text);
    addSubstitution(sub);
    _orderByClause.addExpression(
        '${field.qualifiedName} <-> ${sub.token}');
  }

  /// Reproduce a partial query to use in a loop or other dynamic pattern.
  @override
  SelectQuery fork() {
    final q = SelectQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._distinct = _distinct;
    q._selectClause = _selectClause.clone();
    q._joins = _joins.map((j) => j.clone()).toList();
    q._orderByClause = _orderByClause.clone();
    q._groupByClause = _groupByClause?.clone();
    q._limitClause = _limitClause?.clone();
    q._offsetClause = _offsetClause?.clone();
    q.importWhereClauses(cloner());
    q.importHavingClauses(havingCloner());
    return q;
  }
}
