/// A contiguous slice of cleaned text ready to be consumed by an LLM.
///
/// Each [TextChunk] carries enough context for downstream intelligence modules
/// to trace the chunk back to its origin document and page.
class TextChunk {
  const TextChunk({
    required this.documentId,
    required this.text,
    required this.tokenCount,
    this.pageNumber,
  });

  /// The document this chunk originated from.
  final String documentId;

  /// The clean, human-readable text content of the chunk.
  final String text;

  /// Approximate number of LLM tokens in [text].
  ///
  /// Computed by the [Chunker] implementation; exact precision depends on the
  /// tokenisation strategy in use.
  final int tokenCount;

  /// The page number within the source document, if applicable.
  ///
  /// May be `null` when a chunk spans multiple pages or the source has no
  /// page concept.
  final int? pageNumber;

  TextChunk copyWith({
    String? documentId,
    String? text,
    int? tokenCount,
    int? pageNumber,
  }) {
    return TextChunk(
      documentId: documentId ?? this.documentId,
      text: text ?? this.text,
      tokenCount: tokenCount ?? this.tokenCount,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextChunk &&
          runtimeType == other.runtimeType &&
          documentId == other.documentId &&
          text == other.text &&
          tokenCount == other.tokenCount &&
          pageNumber == other.pageNumber;

  @override
  int get hashCode =>
      documentId.hashCode ^
      text.hashCode ^
      tokenCount.hashCode ^
      pageNumber.hashCode;

  @override
  String toString() =>
      'TextChunk(documentId: $documentId, pageNumber: $pageNumber, '
      'tokenCount: $tokenCount, text: ${text.length > 40 ? '${text.substring(0, 40)}…' : text})';
}
