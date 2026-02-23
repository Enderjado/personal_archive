import '../domain/document.dart';

/// Result of a successful document import.
class ImportResult {
  final Document document;
  final int pageCount;

  const ImportResult({
    required this.document,
    required this.pageCount,
  });

  @override
  String toString() => 'ImportResult(document: ${document.id}, pageCount: $pageCount)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportResult &&
          runtimeType == other.runtimeType &&
          document == other.document &&
          pageCount == other.pageCount;

  @override
  int get hashCode => document.hashCode ^ pageCount.hashCode;
}

/// Orchestrates the import of a document from a raw file path into the system.
///
/// This pipeline handles validation, file storage, metadata extraction, and
/// the initial creation of Document and Page records.
abstract class DocumentPipeline {
  /// Imports a document from the given [sourcePath].
  ///
  /// Returns an [ImportResult] containing the created document and page count.
  /// Throws specific exceptions for validation, storage, or processing errors.
  Future<ImportResult> importFromPath(String sourcePath);

  /// Runs OCR processing for the document with the given [documentId].
  ///
  /// The document must exist and be in [DocumentStatus.imported] status.
  /// Renders each page to an image, extracts text via OCR, and persists
  /// the results.
  ///
  /// Throws [OcrPipelineError] subtypes on failure:
  /// - [DocumentNotFoundError] if the document does not exist.
  /// - [InvalidDocumentStateError] if the document is not in `imported` status.
  /// - [PdfUnreadableError] if the PDF file cannot be read.
  /// - [OcrRenderError] if a page fails to render.
  /// - [OcrEnginePipelineError] if OCR text extraction fails.
  /// - [OcrStorageError] if a storage operation fails during processing.
  Future<void> runOcrForDocument(String documentId);
}
