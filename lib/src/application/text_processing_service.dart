import 'text_processing_errors.dart';

export 'text_processing_errors.dart';

/// Contract for applying text cleaning to all pages of a document and
/// persisting the result as [Page.processedText].
///
/// Implementations must:
/// - Load all pages for the given [documentId] via [PageRepository].
/// - Run [TextProcessor.clean] on each page's `rawText`.
/// - Persist the cleaned text back to storage (single field update only).
/// - Be **idempotent**: re-running the service on a document that has already
///   been processed must not change the stored data or throw an error.
///
/// ### Behaviour for edge cases
/// | Situation | Behaviour |
/// |-----------|-----------|
/// | Document has no pages | Throws [DocumentHasNoPagesError] immediately. |
/// | Page has null `rawText` | Page is silently skipped; `processedText` is left unchanged. |
/// | Page already has `processedText` | Page is skipped; storage is not written again. |
abstract class TextProcessingService {
  /// Processes all eligible pages of the document identified by [documentId].
  ///
  /// Throws [DocumentHasNoPagesError] when the document has no pages.
  /// Throws [TextProcessingStorageError] when a persistence operation fails.
  Future<void> processDocument(String documentId);
}
