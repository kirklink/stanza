import 'package:stanza/src/query.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/insert/insert_clause.dart';


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

  void insert(Field field, dynamic value) {
    _insert.insert(field.name, value, this);
  }

  void insertEntity(Map<String, dynamic> entity) {
    entity.forEach((k, v) {
      _insert.insert(k, v, this);
    });
  }


  InsertQuery fork() {
    var q = InsertQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._insert = _insert.clone();
    return q;

  }


}