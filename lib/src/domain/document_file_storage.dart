abstract class DocumentFileStorage {
  /// Stores a document file from the given [sourceFilePath] for the specified [documentId].
  Future<void> storeForDocument(String documentId, String sourceFilePath);

  /// Returns the deterministic path where the document with [documentId] is stored.
  String pathForDocument(String documentId);

  /// Removes the stored file for the specified [documentId].
  Future<void> removeForDocument(String documentId);
}
