import '../domain/document.dart';
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
    // 1. Validation
    
    // 2. File Storage
    
    // 3. Document Creation
    
    // 4. Page Extraction (Metadata)
    
    // 5. Page Creation
    
    throw UnimplementedError();
  }
}
