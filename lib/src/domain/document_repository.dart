import 'document.dart';
import 'date_time_range.dart';

/// Persistence contract for [Document] entities.
abstract class DocumentRepository {
  /// Creates a new document. Returns the created document or throws [StorageError].
  Future<Document?> create(Document draft);

  /// Updates an existing document. Returns the updated document or throws [StorageError].
  Future<Document?> update(Document document);

  /// Returns the document with [id], or null if not found.
  Future<Document?> findById(String id);

  /// Lists documents, optionally filtered by status, place, and created date range.
  Future<List<Document>> list({
    DocumentStatus? status,
    String? placeId,
    DateTimeRange? createdBetween,
  });

  /// Deletes a document by [id].
  Future<void> delete(String id);
}
