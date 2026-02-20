import '../domain/document.dart';

/// Result of a successful document import.
class ImportResult {
  final Document document;
  final int pageCount;

  const ImportResult({
    required this.document,
    required this.pageCount,
  });

  @override
  String toString() => 'ImportResult(document: ${document.id}, pageCount: $pageCount)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportResult &&
          runtimeType == other.runtimeType &&
          document == other.document &&
          pageCount == other.pageCount;

  @override
  int get hashCode => document.hashCode ^ pageCount.hashCode;
}

/// Orchestrates the import of a document from a raw file path into the system.
///
/// This pipeline handles validation, file storage, metadata extraction, and
/// the initial creation of Document and Page records.
abstract class DocumentPipeline {
  /// Imports a document from the given [sourcePath].
  ///
  /// Returns an [ImportResult] containing the created document and page count.
  /// Throws specific exceptions for validation, storage, or processing errors.
  Future<ImportResult> importFromPath(String sourcePath);
}
