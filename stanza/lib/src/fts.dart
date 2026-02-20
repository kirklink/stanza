/// PostgreSQL full-text search configuration and query type enums.
library;

/// PostgreSQL text search dictionary configuration.
///
/// Controls how text is parsed, stemmed, and indexed.
/// The most common choice is [english] for English content.
enum FtsConfig {
  /// No language-specific processing.
  simple('simple'),

  /// English stemming and stop words (most common choice).
  english('english'),

  /// Spanish stemming and stop words.
  spanish('spanish'),

  /// French stemming and stop words.
  french('french'),

  /// German stemming and stop words.
  german('german'),

  /// Italian stemming and stop words.
  italian('italian'),

  /// Portuguese stemming and stop words.
  portuguese('portuguese'),

  /// Russian stemming and stop words.
  russian('russian'),

  /// Swedish stemming and stop words.
  swedish('swedish'),

  /// Turkish stemming and stop words.
  turkish('turkish'),

  /// Dutch stemming and stop words.
  dutch('dutch'),

  /// Danish stemming and stop words.
  danish('danish'),

  /// Finnish stemming and stop words.
  finnish('finnish'),

  /// Hungarian stemming and stop words.
  hungarian('hungarian'),

  /// Norwegian stemming and stop words.
  norwegian('norwegian'),

  /// Romanian stemming and stop words.
  romanian('romanian');

  /// The PostgreSQL configuration name passed to `to_tsvector` and `tsquery`.
  final String value;

  const FtsConfig(this.value);
}

/// How to parse the search query text into a `tsquery`.
///
/// - [plain]: splits on whitespace, ANDs terms together
/// - [websearch]: Google-like syntax (`"phrase" -exclude OR term`)
/// - [phrase]: proximity matching (terms must appear in order)
enum FtsQueryType {
  /// Splits on whitespace, ANDs terms. Most common for simple queries.
  plain('plainto_tsquery'),

  /// Google-like syntax: `"exact phrase"`, `-exclude`, `OR`.
  websearch('websearch_to_tsquery'),

  /// Proximity matching — terms must appear in order.
  phrase('phraseto_tsquery');

  /// The PostgreSQL function name used to parse the query.
  final String functionName;

  const FtsQueryType(this.functionName);
}
