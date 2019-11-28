import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/insert/insert_clause.dart';

/// Base class for an insert query.
/// 
/// Takes the generated code table from a [StanzaEntity].
class InsertQuery extends Query {

  var _insert = InsertClause();

  InsertQuery(Table table) : super(table);

  @override
  String statement({bool pretty: false}) {
    var br = pretty ? '\n' : ' ';
    var tableName = table?.$name ?? '';
    var insert = _insert.clause ?? '';
    var ibr = br;
    var query = "INSERT INTO $tableName${ibr}$insert;";
    return query;
  }

  /// Insert a [value] into a [field].
  void insert(Field field, dynamic value) {
    _insert.insert(field.name, value, this);
  }

  /// Insert a complete [StanzaEntity] into the database.
  void insertEntity<T>(T entity) {
    if (table.$type != T) {
      var msg = 'Mismatch. The entity is Type $T. The table is type ${table.$type}';
      throw StanzaException(msg);
    }
    var map = table.toDb(entity);
    map.forEach((k, v) {
      _insert.insert(k, v, this);
    });
  }

  /// Reproduce a partial query to use in a loop or other dynamic pattern.
  InsertQuery fork() {
    var q = InsertQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._insert = _insert.clone();
    return q;

  }


}