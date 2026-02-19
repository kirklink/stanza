import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  group('WhereOperation - fullTextMatches', () {
    test('default config and query type', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('cats');
      final stmt = q.statement();
      expect(stmt, contains("to_tsvector('english', mammal.name)"));
      expect(stmt, contains('@@'));
      expect(stmt, contains("plainto_tsquery('english',"));
      expect(q.substitutionValues.values, contains('cats'));
    });

    test('websearch query type', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('"exact" cats -dogs',
            queryType: FtsQueryType.websearch);
      final stmt = q.statement();
      expect(stmt, contains('websearch_to_tsquery'));
      expect(stmt, isNot(contains('plainto_tsquery')));
    });

    test('phrase query type', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('fat cats',
            queryType: FtsQueryType.phrase);
      final stmt = q.statement();
      expect(stmt, contains('phraseto_tsquery'));
    });

    test('custom config', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('gatos',
            config: FtsConfig.spanish);
      final stmt = q.statement();
      expect(stmt, contains("'spanish'"));
      expect(stmt, isNot(contains("'english'")));
    });

    test('search text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches("'; DROP TABLE mammal; --");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
      expect(q.substitutionValues.values,
          contains("'; DROP TABLE mammal; --"));
    });

    test('combined with AND', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('cats')
        ..and(t.color).matches('brown');
      final stmt = q.statement();
      expect(stmt, contains('WHERE'));
      expect(stmt, contains('AND'));
      expect(stmt, contains('@@'));
    });

    test('combined with OR', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('cats')
        ..or(t.color).fullTextMatches('brown');
      final stmt = q.statement();
      expect(stmt, contains('WHERE'));
      expect(stmt, contains('OR'));
    });

    test('with brackets', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name, openBracket: true).fullTextMatches('cats')
        ..or(t.name, closeBracket: true).fullTextMatches('dogs');
      final stmt = q.statement();
      expect(stmt, contains('('));
      expect(stmt, contains(')'));
    });
  });

  group('WhereOperation - isSimilarTo', () {
    test('produces % operator', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).isSimilarTo('jonh');
      final stmt = q.statement();
      expect(stmt, contains('mammal.name %'));
      expect(q.substitutionValues.values, contains('jonh'));
    });

    test('text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).isSimilarTo("'; DROP TABLE mammal; --");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
    });

    test('combined with OR for fuzzy fallback', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('john')
        ..or(t.name).isSimilarTo('john');
      final stmt = q.statement();
      expect(stmt, contains('OR'));
      expect(stmt, contains('%'));
    });

    test('with brackets', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name, openBracket: true).isSimilarTo('cat')
        ..or(t.name, closeBracket: true).isSimilarTo('dog');
      final stmt = q.statement();
      expect(stmt, contains('('));
      expect(stmt, contains(')'));
    });
  });

  group('WhereOperation - isWordSimilarTo', () {
    test('produces %> operator', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).isWordSimilarTo('cat');
      final stmt = q.statement();
      expect(stmt, contains('%>'));
      expect(stmt, contains('mammal.name'));
    });

    test('text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).isWordSimilarTo("'; DROP TABLE;");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
    });
  });

  group('SelectQuery - selectRank', () {
    test('adds ts_rank to SELECT and ORDER BY', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'cats')
        ..where(t.name).fullTextMatches('cats');
      final stmt = q.statement();
      expect(stmt, contains('ts_rank('));
      expect(stmt, contains('AS rank'));
      expect(stmt, contains('ORDER BY ts_rank('));
      expect(stmt, contains('DESC'));
    });

    test('custom alias', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'cats', alias: 'relevance');
      final stmt = q.statement();
      expect(stmt, contains('AS relevance'));
      expect(stmt, isNot(contains('AS rank')));
    });

    test('without auto order by', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'cats', orderByRank: false);
      final stmt = q.statement();
      expect(stmt, contains('ts_rank('));
      expect(stmt, isNot(contains('ORDER BY')));
    });

    test('websearch query type', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'cats -dogs',
            queryType: FtsQueryType.websearch);
      final stmt = q.statement();
      expect(stmt, contains('websearch_to_tsquery'));
    });

    test('custom config', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'gatos', config: FtsConfig.spanish);
      final stmt = q.statement();
      expect(stmt, contains("'spanish'"));
    });

    test('search text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, "'; DROP TABLE mammal;");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
      expect(q.substitutionValues.values,
          contains("'; DROP TABLE mammal;"));
    });
  });

  group('SelectQuery - selectHeadline', () {
    test('adds ts_headline to SELECT', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectHeadline(t.name, 'cats');
      final stmt = q.statement();
      expect(stmt, contains('ts_headline('));
      expect(stmt, contains('AS headline'));
    });

    test('with options', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectHeadline(t.name, 'cats',
            options: 'StartSel=<b>, StopSel=</b>');
      final stmt = q.statement();
      expect(stmt, contains('StartSel=<b>'));
      expect(stmt, contains('StopSel=</b>'));
    });

    test('custom alias', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectHeadline(t.name, 'cats', alias: 'snippet');
      final stmt = q.statement();
      expect(stmt, contains('AS snippet'));
    });

    test('does not add ORDER BY', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectHeadline(t.name, 'cats');
      final stmt = q.statement();
      expect(stmt, isNot(contains('ORDER BY')));
    });

    test('search text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectHeadline(t.name, "'; DROP TABLE;");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
    });
  });

  group('SelectQuery - selectSimilarity', () {
    test('adds similarity to SELECT and ORDER BY', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectSimilarity(t.name, 'jonh');
      final stmt = q.statement();
      expect(stmt, contains('similarity('));
      expect(stmt, contains('AS similarity_score'));
      expect(stmt, contains('ORDER BY similarity('));
      expect(stmt, contains('DESC'));
    });

    test('custom alias', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectSimilarity(t.name, 'jonh', alias: 'score');
      final stmt = q.statement();
      expect(stmt, contains('AS score'));
    });

    test('without auto order by', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectSimilarity(t.name, 'jonh', orderBySimilarity: false);
      final stmt = q.statement();
      expect(stmt, contains('similarity('));
      expect(stmt, isNot(contains('ORDER BY')));
    });

    test('text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectSimilarity(t.name, "'; DROP TABLE;");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
    });
  });

  group('SelectQuery - orderByDistance', () {
    test('adds distance operator to ORDER BY', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderByDistance(t.name, 'jonh');
      final stmt = q.statement();
      expect(stmt, contains('<->'));
      expect(stmt, contains('ORDER BY'));
      expect(stmt, contains('ASC'));
    });

    test('text is parameterized', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderByDistance(t.name, "'; DROP TABLE;");
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
    });

    test('can combine with regular orderBy', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderByDistance(t.name, 'jonh')
        ..orderBy(t.name);
      final stmt = q.statement();
      expect(stmt, contains('<->'));
      expect(stmt, contains('mammal.name ASC'));
    });
  });

  group('Fork preserves FTS state', () {
    test('fork preserves selectRank', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'cats')
        ..where(t.name).fullTextMatches('cats');
      final forked = q.fork();
      final stmt = forked.statement();
      expect(stmt, contains('ts_rank('));
      expect(stmt, contains('AS rank'));
      expect(stmt, contains('@@'));
    });

    test('fork preserves fullTextMatches WHERE', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('cats');
      final forked = q.fork();
      final stmt = forked.statement();
      expect(stmt, contains('to_tsvector('));
      expect(stmt, contains('@@'));
    });

    test('fork is independent', () {
      final q = SelectQuery(t)..selectStar();
      final forked = q.fork();
      forked.selectRank(t.name, 'cats');
      expect(forked.statement(), contains('ts_rank('));
      expect(q.statement(), isNot(contains('ts_rank(')));
    });

    test('fork preserves similarity', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectSimilarity(t.name, 'jonh')
        ..where(t.name).isSimilarTo('jonh');
      final forked = q.fork();
      final stmt = forked.statement();
      expect(stmt, contains('similarity('));
      expect(stmt, contains('%'));
    });
  });

  group('Combined FTS + trigram', () {
    test('FTS with trigram fallback', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).fullTextMatches('database')
        ..or(t.color).isSimilarTo('database');
      final stmt = q.statement();
      expect(stmt, contains('@@'));
      expect(stmt, contains('%'));
      expect(stmt, contains('OR'));
    });

    test('rank + headline + where together', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..selectRank(t.name, 'optimization')
        ..selectHeadline(t.name, 'optimization',
            options: 'StartSel=<b>, StopSel=</b>')
        ..where(t.name).fullTextMatches('optimization');
      final stmt = q.statement();
      expect(stmt, contains('ts_rank('));
      expect(stmt, contains('ts_headline('));
      expect(stmt, contains('@@'));
      expect(stmt, contains('ORDER BY'));
    });
  });
}
