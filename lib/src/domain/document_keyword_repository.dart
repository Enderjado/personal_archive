import 'document_keyword_relation.dart';
import 'keyword.dart';
import 'storage_error.dart';

/// Persistence contract for document–keyword relations (many-to-many).
abstract class DocumentKeywordRepository {
  /// Replaces or updates relations for [documentId] with [relations].
  /// Throws [StorageError] on failure (e.g. foreign key violation).
  Future<void> upsertForDocument(
    String documentId,
    List<DocumentKeywordRelation> relations,
  );

  /// Returns the [Keyword] entities linked to the given [documentId].
  Future<List<Keyword>> listForDocument(String documentId);
}
