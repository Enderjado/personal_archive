/// Contract for synchronizing search indices for a document.
abstract class SearchIndexSync {
  /// Synchronizes the search index for the document with the given [documentId].
  ///
  /// This operation is typically a best-effort side-effect and should not
  /// prevent successful completion of other operations if it fails.
  Future<void> syncDocument(String documentId);
}
