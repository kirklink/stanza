import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/table.dart';

/// The base class to create a Stanza query.
///
/// The methods of Query are shared with all query implementations.
abstract class Query {
  Table _table;

  var _substitutionValues = Map<String, dynamic>();

  Query(this._table);

  Table get table => _table;
  Map<String, dynamic> get substitutionValues => _substitutionValues;

  String statement({bool pretty = false}) {
    throw StanzaException('Statement is not implemented.');
  }

  /// Print a query to the console.
  String toString() {
    if (_substitutionValues.isEmpty) {
      return 'Type: ${this.runtimeType}\n${statement(pretty: true)}';
    }
    return 'Type: ${this.runtimeType}\n${this.runtimeType}\n${statement(pretty: true)}\nsubstitutionValues: ${_substitutionValues.toString()}';
  }

  void addSubstitution(ValueSub sub) {
    _substitutionValues[sub.key] = sub.value;
  }

  void importSubstitutionValues(Map<String, dynamic> subs) {
    _substitutionValues = Map.from(subs);
  }

  Query fork() {
    throw StanzaException('Clone is not implemented.');
  }
}
