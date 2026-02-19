import 'storage_error.dart';
import 'summary.dart';

/// Persistence contract for [Summary] entities (1:1 with document).
abstract class SummaryRepository {
  /// Inserts or updates [summary] by [Summary.documentId]. Throws [StorageError]
  /// on failure (e.g. foreign key violation if document does not exist).
  Future<void> upsert(Summary summary);

  /// Returns the summary for the given [documentId], or null if none exists.
  Future<Summary?> findByDocumentId(String documentId);
}
