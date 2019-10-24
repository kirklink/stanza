import 'package:stanza/src/field.dart';
import 'package:stanza/src/query.dart';


class WherePackage {
  final String operation;
  final Field field;
  final bool openBracket;
  final bool closeBracket;
  final List<String> attachment;
  final Query source;

  WherePackage(this.operation, this.field, this.openBracket, this.closeBracket,
    this.attachment, this.source);
}