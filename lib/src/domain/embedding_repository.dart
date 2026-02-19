import 'embedding.dart';
import 'storage_error.dart';

/// Persistence contract for [Embedding] entities (1:1 with document).
abstract class EmbeddingRepository {
  /// Inserts or updates [embedding] by [Embedding.documentId].
  /// Throws [StorageError] on failure (e.g. foreign key violation).
  Future<void> upsert(Embedding embedding);

  /// Returns the embedding for the given [documentId], or null if none exists.
  Future<Embedding?> findByDocumentId(String documentId);
}

