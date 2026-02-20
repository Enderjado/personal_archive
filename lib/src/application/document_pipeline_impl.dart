import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../domain/document.dart';
import '../domain/page.dart';
import '../domain/document_file_storage.dart';
import '../domain/document_repository.dart';
import '../domain/page_repository.dart';
import '../domain/pdf_metadata.dart';
import 'document_pipeline.dart';
import 'import_validator.dart';
import 'pdf_metadata_reader.dart';

/// Concrete implementation of the [DocumentPipeline].
class DocumentPipelineImpl implements DocumentPipeline {
  const DocumentPipelineImpl({
    required this.validator,
    required this.fileStorage,
    required this.metadataReader,
    required this.documentRepository,
    required this.pageRepository,
  });

  final ImportValidator validator;
  final DocumentFileStorage fileStorage;
  final PdfMetadataReader metadataReader;
  final DocumentRepository documentRepository;
  final PageRepository pageRepository;

  @override
  Future<ImportResult> importFromPath(String sourcePath) async {
    // 1. Validation. We get the metadata here to avoid reading it twice.
    final metadata = await validator.validateFile(sourcePath);

    // 2. File Storage
    final documentId = const Uuid().v4();
    try {
      await fileStorage.storeForDocument(documentId, sourcePath);
    } catch (e) {
      if (e is FileStorageError) rethrow;
      throw FileIoStorageError('Unexpected error during file storage', e);
    }
    final storagePath = fileStorage.pathForDocument(documentId);

    // 3. Document Creation
    final title = p.basenameWithoutExtension(sourcePath);
    final now = DateTime.now().toUtc();
    
    final document = Document(
      id: documentId,
      title: title,
      filePath: storagePath,
      status: DocumentStatus.imported,
      createdAt: now,
      updatedAt: now,
      // confidenceScore and placeId are null initially
    );
    
    await documentRepository.create(document);

    // 4. Page Extraction (Metadata)
    // We already have the metadata from the validation step.
    final pageCount = metadata.pageCount;
    
    // 5. Page Creation
    final pages = List<Page>.generate(pageCount, (index) {
      final pageNumber = index + 1;
      return Page(
        id: const Uuid().v4(),
        documentId: documentId,
        pageNumber: pageNumber,
      );
    });

    await pageRepository.insertAll(pages);

    return ImportResult(
      document: document,
      pageCount: pageCount,
    );
  }
}
