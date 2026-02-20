import 'package:mocktail/mocktail.dart';
import 'package:personal_archive/src/application/document_pipeline_impl.dart';
import 'package:personal_archive/src/application/import_validator.dart';
import 'package:personal_archive/src/application/search_index_sync.dart';
import 'package:personal_archive/src/application/pdf_metadata_reader.dart'; // Added missing import
import 'package:personal_archive/src/domain/document.dart';
import 'package:personal_archive/src/domain/document_file_storage.dart';
import 'package:personal_archive/src/domain/document_repository.dart';
import 'package:personal_archive/src/domain/page_repository.dart';
import 'package:personal_archive/src/domain/pdf_metadata.dart';
import 'package:personal_archive/src/domain/import_validation_error.dart';
import 'package:personal_archive/src/domain/file_storage_error.dart';
import 'package:personal_archive/src/domain/storage_error.dart';
import 'package:flutter_test/flutter_test.dart'; // Changed from package:test


class MockImportValidator extends Mock implements ImportValidator {}
class MockDocumentFileStorage extends Mock implements DocumentFileStorage {}
class MockPdfMetadataReader extends Mock implements PdfMetadataReader {} // This is just a placeholder since we use Validator for metadata
class MockDocumentRepository extends Mock implements DocumentRepository {}
class MockPageRepository extends Mock implements PageRepository {}
class MockSearchIndexSync extends Mock implements SearchIndexSync {}

void main() {
  group('DocumentPipelineImpl', () {
    late DocumentPipelineImpl pipeline;
    late MockImportValidator mockValidator;
    late MockDocumentFileStorage mockFileStorage;
    late MockPdfMetadataReader mockMetadataReader;
    late MockDocumentRepository mockDocumentRepository;
    late MockPageRepository mockPageRepository;
    late MockSearchIndexSync mockSearchIndexSync;

    setUp(() {
      mockValidator = MockImportValidator();
      mockFileStorage = MockDocumentFileStorage();
      mockMetadataReader = MockPdfMetadataReader();
      mockDocumentRepository = MockDocumentRepository();
      mockPageRepository = MockPageRepository();
      mockSearchIndexSync = MockSearchIndexSync();

      when(() => mockSearchIndexSync.syncDocument(any())).thenAnswer((_) async {});

      pipeline = DocumentPipelineImpl(
        validator: mockValidator,
        fileStorage: mockFileStorage,
        metadataReader: mockMetadataReader,
        documentRepository: mockDocumentRepository,
        pageRepository: mockPageRepository,
        searchIndexSync: mockSearchIndexSync,
      );
      
      // Register fallback values for arguments used in `any()` or `captureAny()`
      registerFallbackValue(
        Document(
          id: 'test-id',
          title: 'test',
          filePath: 'test',
          status: DocumentStatus.imported,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    test('importFromPath successfully creates document and pages', () async {
      // Arrange
      const sourcePath = '/tmp/test_document.pdf';
      const storagePath = '/app/storage/uuid.pdf';
      const pageCount = 3;
      
      when(() => mockValidator.validateFile(sourcePath))
          .thenAnswer((_) async => const PdfMetadata(pageCount: pageCount));
          
      when(() => mockFileStorage.storeForDocument(any(), sourcePath))
          .thenAnswer((_) async {});
          
      when(() => mockFileStorage.pathForDocument(any()))
          .thenReturn(storagePath);
          
      when(() => mockDocumentRepository.create(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments.first as Document);
          
      when(() => mockPageRepository.insertAll(any()))
          .thenAnswer((_) async {});

      // Act
      final result = await pipeline.importFromPath(sourcePath);

      // Assert
      expect(result.pageCount, equals(pageCount));
      expect(result.document.status, equals(DocumentStatus.imported));
      expect(result.document.filePath, equals(storagePath));
      expect(result.document.title, equals('test_document')); // basenameWithoutExtension

      // Verify interactions
      verify(() => mockValidator.validateFile(sourcePath)).called(1);
      verify(() => mockFileStorage.storeForDocument(any(), sourcePath)).called(1);
      verify(() => mockDocumentRepository.create(any())).called(1);
      
      // Verify pages creation
      final capturedPages = verify(() => mockPageRepository.insertAll(captureAny())).captured.single as List;
      expect(capturedPages.length, equals(pageCount));
      expect(capturedPages[0].pageNumber, equals(1));
      expect(capturedPages[2].pageNumber, equals(3));
      
      // Verify FTS sync
      verify(() => mockSearchIndexSync.syncDocument(any())).called(1);
    });

    test('importFromPath fails on validation error and aborts', () async {
      // Arrange
      const sourcePath = '/tmp/invalid.pdf';
      final error = FileDoesNotExistError(sourcePath);
      
      when(() => mockValidator.validateFile(sourcePath)).thenThrow(error);

      // Act & Assert
      expect(
        () => pipeline.importFromPath(sourcePath),
        throwsA(isA<FileDoesNotExistError>()),
      );

      // Verify no side effects
      verify(() => mockValidator.validateFile(sourcePath)).called(1);
      verifyNever(() => mockFileStorage.storeForDocument(any(), any()));
      verifyNever(() => mockDocumentRepository.create(any()));
      verifyNever(() => mockPageRepository.insertAll(any()));
    });

    test('importFromPath fails on file storage error and aborts', () async {
      // Arrange
      const sourcePath = '/tmp/test.pdf';
      const metadata = PdfMetadata(pageCount: 5);
      
      when(() => mockValidator.validateFile(sourcePath)).thenAnswer((_) async => metadata);
      when(() => mockFileStorage.storeForDocument(any(), sourcePath))
          .thenThrow(const FileIoStorageError('Disk full'));

      // Act & Assert
      await expectLater(
        () => pipeline.importFromPath(sourcePath),
        throwsA(isA<FileIoStorageError>()),
      );

      // Verify validation ran but stopped at storage
      verify(() => mockValidator.validateFile(sourcePath)).called(1);
      verify(() => mockFileStorage.storeForDocument(any(), sourcePath)).called(1);
      verifyNever(() => mockDocumentRepository.create(any()));
      verifyNever(() => mockPageRepository.insertAll(any()));
    });

    test('importFromPath cleans up file if document creation fails', () async {
      // Arrange
      const sourcePath = '/tmp/test2.pdf'; // Use unique path
      const metadata = PdfMetadata(pageCount: 5);
      
      when(() => mockValidator.validateFile(sourcePath)).thenAnswer((_) async => metadata);
      when(() => mockFileStorage.storeForDocument(any(), sourcePath)).thenAnswer((_) async {});
      when(() => mockFileStorage.pathForDocument(any())).thenReturn('/storage/path.pdf');
      
      // Simulate DB failure
      when(() => mockDocumentRepository.create(any()))
          .thenThrow(const StorageUnknownError('DB Connection failed'));
          
      // Cleanup mock
      when(() => mockFileStorage.removeForDocument(any())).thenAnswer((_) async {});

      // Act & Assert
      await expectLater(
        () => pipeline.importFromPath(sourcePath),
        throwsA(isA<StorageUnknownError>()),
      );

      // Verify flow
      verify(() => mockValidator.validateFile(sourcePath)).called(1);
      verify(() => mockFileStorage.storeForDocument(any(), sourcePath)).called(1);
      verify(() => mockDocumentRepository.create(any())).called(1);
      
      // Verify cleanup
      verify(() => mockFileStorage.removeForDocument(any())).called(1);
      verifyNever(() => mockPageRepository.insertAll(any()));
    });

    test('importFromPath cleans up document and file if page insertion fails', () async {
      // Arrange
      const sourcePath = '/tmp/test3.pdf'; // Use unique path
      const metadata = PdfMetadata(pageCount: 5);
      
      when(() => mockValidator.validateFile(sourcePath)).thenAnswer((_) async => metadata);
      when(() => mockFileStorage.storeForDocument(any(), sourcePath)).thenAnswer((_) async {});
      when(() => mockFileStorage.pathForDocument(any())).thenReturn('/storage/path.pdf');
      when(() => mockDocumentRepository.create(any())).thenAnswer((_) async => Document(
            id: 'id',
            title: 'test',
            filePath: 'path',
            status: DocumentStatus.imported,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
      
      // Simulate Page DB failure
      when(() => mockPageRepository.insertAll(any()))
          .thenThrow(const StorageUnknownError('Page Insert Failed'));

      // Cleanup mocks
      when(() => mockDocumentRepository.delete(any())).thenAnswer((_) async {});
      when(() => mockFileStorage.removeForDocument(any())).thenAnswer((_) async {});

      // Act & Assert
      await expectLater(
        () => pipeline.importFromPath(sourcePath),
        throwsA(isA<StorageUnknownError>()),
      );

      // Verify flow
      verify(() => mockValidator.validateFile(sourcePath)).called(1);
      verify(() => mockFileStorage.storeForDocument(any(), sourcePath)).called(1);
      verify(() => mockDocumentRepository.create(any())).called(1);
      verify(() => mockPageRepository.insertAll(any())).called(1);
      
      // Verify cleanup
      verify(() => mockDocumentRepository.delete(any())).called(1);
      verify(() => mockFileStorage.removeForDocument(any())).called(1);
    });
  });
}
