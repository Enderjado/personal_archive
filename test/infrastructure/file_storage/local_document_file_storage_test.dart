import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_archive/infrastructure/file_storage/local_document_file_storage.dart';
import 'package:personal_archive/src/domain/file_storage_error.dart';

void main() {
  late Directory tempDir;
  late LocalDocumentFileStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('local_document_file_storage_test_');
    storage = LocalDocumentFileStorage(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalDocumentFileStorage', () {
    test('creates storage root if it does not exist', () {
      final newRoot = p.join(tempDir.path, 'new_root');
      expect(Directory(newRoot).existsSync(), isFalse);

      LocalDocumentFileStorage(newRoot);

      expect(Directory(newRoot).existsSync(), isTrue);
    });

    test('pathForDocument returns deterministic path', () {
      final documentId = 'doc-123';
      final expectedPath = p.join(tempDir.path, '$documentId.pdf');

      expect(storage.pathForDocument(documentId), expectedPath);
    });

    test('storeForDocument copies file successfully', () async {
      final documentId = 'doc-456';
      final sourceFile = File(p.join(tempDir.path, 'source.pdf'));
      await sourceFile.writeAsString('dummy pdf content');

      await storage.storeForDocument(documentId, sourceFile.path);

      final destinationPath = storage.pathForDocument(documentId);
      final destinationFile = File(destinationPath);

      expect(await destinationFile.exists(), isTrue);
      expect(await destinationFile.readAsString(), 'dummy pdf content');
    });

    test('storeForDocument throws FileNotFoundStorageError if source does not exist', () async {
      final documentId = 'doc-789';
      final nonExistentPath = p.join(tempDir.path, 'non_existent.pdf');

      expect(
        () => storage.storeForDocument(documentId, nonExistentPath),
        throwsA(isA<FileNotFoundStorageError>()),
      );
    });

    test('removeForDocument deletes file successfully', () async {
      final documentId = 'doc-abc';
      final destinationPath = storage.pathForDocument(documentId);
      final destinationFile = File(destinationPath);
      await destinationFile.writeAsString('dummy content to delete');

      expect(await destinationFile.exists(), isTrue);

      await storage.removeForDocument(documentId);

      expect(await destinationFile.exists(), isFalse);
    });

    test('removeForDocument does nothing if file does not exist', () async {
      final documentId = 'doc-def';
      final destinationPath = storage.pathForDocument(documentId);
      final destinationFile = File(destinationPath);

      expect(await destinationFile.exists(), isFalse);

      // Should not throw
      await storage.removeForDocument(documentId);
    });
  });
}
