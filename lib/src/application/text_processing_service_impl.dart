import '../domain/page_repository.dart';
import '../domain/storage_error.dart';
import '../domain/text_processor.dart';
import 'text_processing_errors.dart';
import 'text_processing_service.dart';

/// Concrete implementation of [TextProcessingService].
///
/// Loads pages via [PageRepository], cleans each page's `rawText` with
/// [TextProcessor], and persists the result back as `processedText`.
///
/// ### Pages with absent rawText
/// Pages whose `rawText` is `null` are silently skipped. Their `processedText`
/// is left untouched and no storage write is issued. This is intentional:
/// a partially OCR-processed document should not block text processing for
/// the pages that do have text.
///
/// This class has no dependency on UI or Flutter; it can be used from a
/// background isolate, a pipeline step, or a test without any additional setup.
class TextProcessingServiceImpl implements TextProcessingService {
  const TextProcessingServiceImpl({
    required this.pageRepository,
    required this.textProcessor,
  });

  final PageRepository pageRepository;
  final TextProcessor textProcessor;

  @override
  Future<void> processDocument(String documentId) async {
    final pages = await pageRepository.findByDocumentId(documentId);

    if (pages.isEmpty) {
      throw DocumentHasNoPagesError(documentId);
    }

    for (final page in pages) {
      final raw = page.rawText;
      // Skip pages that have not yet been through OCR; their processedText
      // is left as-is (null) so a subsequent run can pick them up once OCR
      // completes.
      if (raw == null) continue;

      final cleaned = textProcessor.clean(raw);
      final updated = page.copyWith(processedText: cleaned);

      try {
        await pageRepository.update(updated);
      } on StorageError catch (e) {
        throw TextProcessingStorageError(documentId: documentId, cause: e);
      } catch (e) {
        throw TextProcessingStorageError(documentId: documentId, cause: e);
      }
    }
  }
}
