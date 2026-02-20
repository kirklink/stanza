/// PostgreSQL full-text search configuration and query type enums.
library;

/// PostgreSQL text search dictionary configuration.
///
/// Controls how text is parsed, stemmed, and indexed.
/// The most common choice is [english] for English content.
enum FtsConfig {
  simple('simple'),
  english('english'),
  spanish('spanish'),
  french('french'),
  german('german'),
  italian('italian'),
  portuguese('portuguese'),
  russian('russian'),
  swedish('swedish'),
  turkish('turkish'),
  dutch('dutch'),
  danish('danish'),
  finnish('finnish'),
  hungarian('hungarian'),
  norwegian('norwegian'),
  romanian('romanian');

  final String value;
  const FtsConfig(this.value);
}

/// How to parse the search query text into a `tsquery`.
///
/// - [plain]: splits on whitespace, ANDs terms together
/// - [websearch]: Google-like syntax (`"phrase" -exclude OR term`)
/// - [phrase]: proximity matching (terms must appear in order)
enum FtsQueryType {
  plain('plainto_tsquery'),
  websearch('websearch_to_tsquery'),
  phrase('phraseto_tsquery');

  final String functionName;
  const FtsQueryType(this.functionName);
}
