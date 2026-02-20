/// Configuration for the PDF import pipeline.
class ImportConfiguration {
  const ImportConfiguration({
    this.maxFileSizeBytes = 50 * 1024 * 1024, // 50 MB default
    this.maxPageCount = 1000, // 1000 pages default
  });

  /// The maximum allowed file size in bytes.
  final int maxFileSizeBytes;

  /// The maximum allowed number of pages in a PDF.
  final int maxPageCount;
}
