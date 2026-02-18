import 'package:stanza/src/field.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/value_substitution.dart';

/// Builder for the SET clause within ON CONFLICT ... DO UPDATE.
class ConflictSetBuilder {
  final Query _source;
  final Map<String, String> _clauses = {};

  ConflictSetBuilder(this._source);

  /// Target a field to update on conflict.
  ConflictSetValue column(Field field) {
    return ConflictSetValue(field, this, _source);
  }

  String get clause {
    return _clauses.entries.map((e) => '${e.key} = ${e.value}').join(', ');
  }

  bool get isEmpty => _clauses.isEmpty;

  ConflictSetBuilder clone(Query newSource) {
    final b = ConflictSetBuilder(newSource);
    b._clauses.addAll(_clauses);
    return b;
  }
}

/// Type-safe value setter for ON CONFLICT ... DO UPDATE SET columns.
class ConflictSetValue {
  final Field field;
  final ConflictSetBuilder _builder;
  final Query _source;

  ConflictSetValue(this.field, this._builder, this._source);

  ConflictSetBuilder _attach(dynamic value) {
    final sub = ValueSub('${field.name}_conflict', value);
    _source.addSubstitution(sub);
    _builder._clauses[field.name] = sub.token;
    return _builder;
  }

  /// Set the value to a number.
  ConflictSetBuilder number(num number) => _attach(number);

  /// Set the value to an integer.
  ConflictSetBuilder integer(int integer) => _attach(integer);

  /// Set the value to a double (float).
  ConflictSetBuilder float(double float) => _attach(float);

  /// Set the value to a string.
  ConflictSetBuilder string(String string) => _attach(string);

  /// Set the value to a datetime.
  ConflictSetBuilder datetime(DateTime datetime) => _attach(datetime);

  /// Set the value to a boolean.
  ConflictSetBuilder boolean(bool boolean) => _attach(boolean);

  /// Set the value to a dynamic value.
  ConflictSetBuilder any(dynamic value) => _attach(value);
}

/// Represents an ON CONFLICT clause for INSERT queries.
class ConflictClause {
  final List<Field> target;
  final bool _doNothing;
  final ConflictSetBuilder? _setBuilder;

  ConflictClause.doNothing({required this.target})
      : _doNothing = true,
        _setBuilder = null;

  ConflictClause.doUpdate({
    required this.target,
    required ConflictSetBuilder setBuilder,
  })  : _doNothing = false,
        _setBuilder = setBuilder;

  String get clause {
    final targetStr = target.map((f) => f.name).join(', ');
    if (_doNothing) return 'ON CONFLICT ($targetStr) DO NOTHING';
    return 'ON CONFLICT ($targetStr) DO UPDATE SET ${_setBuilder!.clause}';
  }

  ConflictClause clone(Query newSource) {
    if (_doNothing) {
      return ConflictClause.doNothing(target: List.from(target));
    }
    return ConflictClause.doUpdate(
      target: List.from(target),
      setBuilder: _setBuilder!.clone(newSource),
    );
  }
}
