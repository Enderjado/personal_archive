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
