/// Result of a successful OCR run for a single document.
///
/// [aggregateConfidence] is the arithmetic mean of the per-page OCR confidence
/// values (0.0–1.0). For documents whose pages returned no confidence score,
/// the contributing pages are excluded from the average; if no page reported a
/// score the field is `null`.
class OcrResult {
  const OcrResult({
    required this.documentId,
    required this.pageCount,
    this.aggregateConfidence,
  });

  /// The ID of the document that was processed.
  final String documentId;

  /// The number of pages that were processed.
  final int pageCount;

  /// The arithmetic mean OCR confidence across all processed pages, or `null`
  /// when no page returned a confidence value.
  final double? aggregateConfidence;

  @override
  String toString() =>
      'OcrResult(documentId: $documentId, pageCount: $pageCount, '
      'aggregateConfidence: $aggregateConfidence)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrResult &&
          runtimeType == other.runtimeType &&
          documentId == other.documentId &&
          pageCount == other.pageCount &&
          aggregateConfidence == other.aggregateConfidence;

  @override
  int get hashCode =>
      documentId.hashCode ^ pageCount.hashCode ^ aggregateConfidence.hashCode;
}
