import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_page_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'sqlite_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqlitePageRepository', () {
    late MigrationDb db;
    late SqlitePageRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
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

    test(
      'insertAll throws when inserting duplicate (document_id, page_number)',
      () async {
        const documentId = 'doc-for-duplicate-pages';

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
            null,
            null,
            0,
            0,
          ],
        );

        final pages = <Page>[
          Page(
            id: 'page-1',
            documentId: documentId,
            pageNumber: 1,
            rawText: 'raw one',
            processedText: 'processed one',
            ocrConfidence: 0.9,
          ),
          Page(
            id: 'page-duplicate',
            documentId: documentId,
            pageNumber: 1, // duplicate for same documentId
            rawText: 'raw dup',
            processedText: 'processed dup',
            ocrConfidence: 0.7,
          ),
        ];

        await expectLater(
          () => repo.insertAll(pages),
          throwsA(isA<StorageError>()),
        );
      },
    );
  });
}

