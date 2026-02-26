/// Contract for cleaning raw OCR text before it is passed to an LLM.
///
/// Implementations must be deterministic: the same [raw] input combined with
/// the same runtime configuration must always produce the same output.
abstract class TextProcessor {
  /// Cleans [raw] OCR text and returns a normalised string ready for chunking.
  ///
  /// - Returns an empty string when [raw] is empty or contains only whitespace.
  /// - Never throws; recoverable noise is silently corrected.
  String clean(String raw);
}
