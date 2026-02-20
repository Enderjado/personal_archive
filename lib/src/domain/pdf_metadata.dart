/// Metadata extracted from a PDF file prior to full page processing.
///
/// Phase 2 only requires [pageCount]; additional fields (e.g. title, author)
/// may be added in later phases without breaking existing callers.
class PdfMetadata {
  const PdfMetadata({required this.pageCount});

  /// Total number of pages in the PDF.
  final int pageCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfMetadata &&
          runtimeType == other.runtimeType &&
          pageCount == other.pageCount;

  @override
  int get hashCode => pageCount.hashCode;

  @override
  String toString() => 'PdfMetadata(pageCount: $pageCount)';
}
