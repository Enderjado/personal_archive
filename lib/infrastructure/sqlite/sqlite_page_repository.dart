import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'package:personal_archive/src/domain/domain.dart';

/// SQLite-backed implementation of [PageRepository].
class SqlitePageRepository implements PageRepository {
  SqlitePageRepository(this._db);

  final MigrationDb _db;

  @override
  Future<void> insertAll(List<Page> pages) {
    if (pages.isEmpty) {
      return Future.value();
    }

    return _db.transaction(() async {
      try {
        for (final page in pages) {
          await _db.execute(
            '''
            INSERT INTO pages (
              id,
              document_id,
              page_number,
              raw_text,
              processed_text,
              ocr_confidence
            ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [
              page.id,
              page.documentId,
              page.pageNumber,
              page.rawText,
              page.processedText,
              page.ocrConfidence,
            ],
          );
        }
      } catch (e) {
        throw StorageUnknownError(e);
      }
    });
  }

  @override
  Future<List<Page>> findByDocumentId(String documentId) {
    // Implemented in the next commit (Commit 3).
    throw UnimplementedError(
      'findByDocumentId will be implemented in a subsequent commit.',
    );
  }
}

