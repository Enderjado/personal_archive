import 'dart:io';
import 'package:path/path.dart' as p;
import '../../src/domain/document_file_storage.dart';
import '../../src/domain/file_storage_error.dart';

/// A local file system implementation of [DocumentFileStorage].
class LocalDocumentFileStorage implements DocumentFileStorage {
  final String _storageRoot;

  /// Creates a new [LocalDocumentFileStorage] with the given [_storageRoot].
  ///
  /// Throws an [InvalidStorageRootError] if the root directory cannot be created
  /// or accessed.
  LocalDocumentFileStorage(this._storageRoot) {
    _ensureRootExists();
  }

  void _ensureRootExists() {
    try {
      final dir = Directory(_storageRoot);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      throw InvalidStorageRootError('Failed to create storage root: $_storageRoot', e);
    }
  }

  @override
  String pathForDocument(String documentId) {
    return p.join(_storageRoot, '$documentId.pdf');
  }

  @override
  Future<void> storeForDocument(String documentId, String sourceFilePath) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw FileNotFoundStorageError(sourceFilePath);
    }

    final destinationPath = pathForDocument(documentId);
    try {
      await sourceFile.copy(destinationPath);
    } catch (e) {
      throw FileIoStorageError('Failed to copy file to $destinationPath', e);
    }
  }

  @override
  Future<void> removeForDocument(String documentId) async {
    final file = File(pathForDocument(documentId));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        throw FileIoStorageError('Failed to delete file at ${file.path}', e);
      }
    }
  }
}
