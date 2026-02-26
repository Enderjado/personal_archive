/// Configuration for the text-processing pipeline used before LLM calls.
///
/// Follows the externalised-configuration pattern used elsewhere in the domain
/// (see [OcrConfig]). All fields are optional; defaults produce a safe,
/// conservative clean without removing any content.
class TextProcessingConfig {
  const TextProcessingConfig({
    this.headerPatterns = const [],
    this.footerPatterns = const [],
  });

  /// Regular-expression strings that identify recurring page headers.
  ///
  /// Any line whose *entire* content matches one of these patterns is removed.
  /// Patterns are treated as case-sensitive unless the pattern itself includes
  /// the `(?i)` flag.
  ///
  /// Example: `[r'Page \d+ of \d+', r'CONFIDENTIAL']`
  final List<String> headerPatterns;

  /// Regular-expression strings that identify recurring page footers.
  ///
  /// Removal follows the same rules as [headerPatterns].
  final List<String> footerPatterns;
}
