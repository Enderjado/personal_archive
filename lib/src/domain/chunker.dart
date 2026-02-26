import 'text_chunk.dart';

/// Contract for splitting cleaned text into LLM-friendly [TextChunk]s.
///
/// Implementations must be deterministic: identical inputs always produce
/// identical output lists.
abstract class Chunker {
  /// Splits [cleaned] text originating from [documentId] into a list of
  /// [TextChunk]s that each fit within the configured token budget.
  ///
  /// - Returns an empty list when [cleaned] is empty.
  /// - Each returned chunk has a non-empty [TextChunk.text] and a positive
  ///   [TextChunk.tokenCount].
  /// - The optional [pageNumber] is forwarded to every produced chunk.
  List<TextChunk> chunk(
    String cleaned, {
    required String documentId,
    int? pageNumber,
  });
}
