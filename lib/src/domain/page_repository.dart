import 'page.dart';
import 'storage_error.dart';

/// Persistence contract for [Page] entities.
abstract class PageRepository {
  /// Inserts all [pages] in a single transaction. Throws [StorageError] on failure
  /// (e.g. foreign key violation if document does not exist).
  Future<void> insertAll(List<Page> pages);

  /// Returns pages for the given [documentId], ordered by [Page.pageNumber] ascending.
  /// Returns an empty list if the document has no pages.
  Future<List<Page>> findByDocumentId(String documentId);
}
