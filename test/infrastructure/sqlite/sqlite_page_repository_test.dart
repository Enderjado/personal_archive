import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class Sqlite3MigrationDb implements MigrationDb {
  Sqlite3MigrationDb(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
  }

  final sqlite.Database _db;

  @override
  Future<void> execute(String sql, [List<Object?> parameters = const []]) async {
    _db.execute(sql, parameters);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    final result = _db.select(sql, parameters);
    return result
        .map<Map<String, Object?>>((row) => Map<String, Object?>.from(row))
        .toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    _db.execute('BEGIN');
    try {
      final result = await action();
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

Future<List<Migration>> _loadTestMigrations() async {
  final initSql =
      await rootBundle.loadString('assets/sql/migrations/001_init_core_schema.sql');
  final placesSql =
      await rootBundle.loadString('assets/sql/migrations/002_add_places.sql');
  final documentsAndPagesSql = await rootBundle
      .loadString('assets/sql/migrations/003_add_documents_and_pages.sql');
  final summariesSql =
      await rootBundle.loadString('assets/sql/migrations/004_add_summaries.sql');
  final keywordsSql =
      await rootBundle.loadString('assets/sql/migrations/005_add_keywords.sql');
  final documentKeywordsSql = await rootBundle
      .loadString('assets/sql/migrations/006_add_document_keywords.sql');
  final embeddingsSql =
      await rootBundle.loadString('assets/sql/migrations/007_add_embeddings.sql');
  final documentsFtsSql =
      await rootBundle.loadString('assets/sql/migrations/008_add_documents_fts.sql');

  return <Migration>[
    Migration(name: '001_init_core_schema', sql: initSql),
    Migration(name: '002_add_places', sql: placesSql),
    Migration(name: '003_add_documents_and_pages', sql: documentsAndPagesSql),
    Migration(name: '004_add_summaries', sql: summariesSql),
    Migration(name: '005_add_keywords', sql: keywordsSql),
    Migration(name: '006_add_document_keywords', sql: documentKeywordsSql),
    Migration(name: '007_add_embeddings', sql: embeddingsSql),
    Migration(name: '008_add_documents_fts', sql: documentsFtsSql),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqlitePageRepository', () {
    late MigrationDb db;
    late SqlitePageRepository repo;

    setUp(() async {
      final rawDb = sqlite.sqlite3.openInMemory();
      db = Sqlite3MigrationDb(rawDb);
      final runner = MigrationRunner(
        db: db,
        loadMigrations: _loadTestMigrations,
      );
      await runner.runAll();
      repo = SqlitePageRepository(db);
    });

    test(
      'insertAll then findByDocumentId returns pages with matching fields in page_number order',
      () async {
        const documentId = 'doc-for-pages';

        // Insert a backing document to satisfy the foreign key.
        await db.execute(
          '''
          INSERT INTO documents (
            id, title, file_path, status, confidence_score,
            place_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            documentId,
            'Doc Title',
            '/path/to/doc.pdf',
            DocumentStatus.imported.name,
            0.9,
            null,
            0,
            0,
          ],
        );

        final pages = <Page>[
          Page(
            id: 'page-2',
            documentId: documentId,
            pageNumber: 2,
            rawText: 'raw two',
            processedText: 'processed two',
            ocrConfidence: 0.8,
          ),
          Page(
            id: 'page-1',
            documentId: documentId,
            pageNumber: 1,
            rawText: 'raw one',
            processedText: 'processed one',
            ocrConfidence: 0.9,
          ),
          Page(
            id: 'page-3',
            documentId: documentId,
            pageNumber: 3,
            rawText: 'raw three',
            processedText: 'processed three',
            ocrConfidence: 0.7,
          ),
        ];

        await repo.insertAll(pages);

        final found = await repo.findByDocumentId(documentId);

        expect(found, hasLength(3));
        // Ensure ordering by page_number ascending.
        expect(found.map((p) => p.pageNumber), [1, 2, 3]);

        final page1 = found[0];
        expect(page1.id, 'page-1');
        expect(page1.documentId, documentId);
        expect(page1.rawText, 'raw one');
        expect(page1.processedText, 'processed one');
        expect(page1.ocrConfidence, closeTo(0.9, 1e-9));

        final page2 = found[1];
        expect(page2.id, 'page-2');
        expect(page2.documentId, documentId);
        expect(page2.rawText, 'raw two');
        expect(page2.processedText, 'processed two');
        expect(page2.ocrConfidence, closeTo(0.8, 1e-9));

        final page3 = found[2];
        expect(page3.id, 'page-3');
        expect(page3.documentId, documentId);
        expect(page3.rawText, 'raw three');
        expect(page3.processedText, 'processed three');
        expect(page3.ocrConfidence, closeTo(0.7, 1e-9));
      },
    );
  });
}

