import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_document_keyword_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_keyword_repository.dart';
import 'package:personal_archive/src/domain/domain.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'sqlite_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteKeywordRepository', () {
    late MigrationDb db;
    late SqliteKeywordRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
      repo = SqliteKeywordRepository(db);
    });

    test('getOrCreate returns new keyword with correct value, type, globalFrequency 0',
        () async {
      final keyword = await repo.getOrCreate('bank', 'topic');
      expect(keyword.value, 'bank');
      expect(keyword.type, 'topic');
      expect(keyword.globalFrequency, 0);
      expect(keyword.id, isNotEmpty);
      expect(keyword.createdAt, isNotNull);
    });

    test('getOrCreate with same value and type returns same keyword (reuse)', () async {
      final k1 = await repo.getOrCreate('invoice', 'type');
      final k2 = await repo.getOrCreate('invoice', 'type');
      expect(k2.id, k1.id);
      expect(k2.value, k1.value);
      expect(k2.type, k1.type);
    });

    test('incrementGlobalFrequency increases globalFrequency', () async {
      final k1 = await repo.getOrCreate('transaction', 'topic');
      expect(k1.globalFrequency, 0);

      await repo.incrementGlobalFrequency(k1.id);

      final k2 = await repo.getOrCreate('transaction', 'topic');
      expect(k2.id, k1.id);
      expect(k2.globalFrequency, 1);
    });
  });

  group('SqliteDocumentKeywordRepository', () {
    late MigrationDb db;
    late SqliteKeywordRepository keywordRepo;
    late SqliteDocumentKeywordRepository docKeywordRepo;

    setUp(() async {
      db = await createMigratedTestDb();
      keywordRepo = SqliteKeywordRepository(db);
      docKeywordRepo = SqliteDocumentKeywordRepository(db);
    });

    Future<void> insertDocument(String documentId) async {
      await db.execute(
        '''
        INSERT INTO documents (
          id, title, file_path, status, confidence_score,
          place_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          documentId,
          'Test Doc',
          '/path/to/doc.pdf',
          DocumentStatus.imported.name,
          null,
          null,
          0,
          0,
        ],
      );
    }

    test('upsertForDocument then listForDocument returns linked keywords', () async {
      const documentId = 'doc-with-keywords';
      await insertDocument(documentId);

      final k1 = await keywordRepo.getOrCreate('bank', 'topic');
      final k2 = await keywordRepo.getOrCreate('invoice', 'type');
      final relations = [
        DocumentKeywordRelation(
          id: 'rel-1',
          documentId: documentId,
          keywordId: k1.id,
          weight: 0.9,
          confidence: 0.95,
          source: 'llm',
        ),
        DocumentKeywordRelation(
          id: 'rel-2',
          documentId: documentId,
          keywordId: k2.id,
          weight: 0.7,
          confidence: 0.8,
        ),
      ];
      await docKeywordRepo.upsertForDocument(documentId, relations);

      final keywords = await docKeywordRepo.listForDocument(documentId);
      expect(keywords.length, 2);
      final ids = keywords.map((k) => k.id).toSet();
      expect(ids, contains(k1.id));
      expect(ids, contains(k2.id));
      final values = keywords.map((k) => k.value).toSet();
      expect(values, contains('bank'));
      expect(values, contains('invoice'));
    });

    test('second upsertForDocument replaces relations (no stale relations)', () async {
      const documentId = 'doc-replace-keywords';
      await insertDocument(documentId);

      final k1 = await keywordRepo.getOrCreate('old', 'topic');
      await docKeywordRepo.upsertForDocument(
        documentId,
        [
          DocumentKeywordRelation(
            id: 'rel-old',
            documentId: documentId,
            keywordId: k1.id,
            weight: 0.5,
            confidence: 0.5,
          ),
        ],
      );

      final k2 = await keywordRepo.getOrCreate('new', 'topic');
      await docKeywordRepo.upsertForDocument(
        documentId,
        [
          DocumentKeywordRelation(
            id: 'rel-new',
            documentId: documentId,
            keywordId: k2.id,
            weight: 0.8,
            confidence: 0.9,
          ),
        ],
      );

      final keywords = await docKeywordRepo.listForDocument(documentId);
      expect(keywords.length, 1);
      expect(keywords.single.id, k2.id);
      expect(keywords.single.value, 'new');
    });

    test('upsertForDocument throws StorageConstraintError for invalid documentId',
        () async {
      const documentId = 'non-existent-doc';

      final k1 = await keywordRepo.getOrCreate('orphan', 'topic');
      final relations = [
        DocumentKeywordRelation(
          id: 'rel-orphan',
          documentId: documentId,
          keywordId: k1.id,
          weight: 0.4,
          confidence: 0.6,
        ),
      ];

      await expectLater(
        () => docKeywordRepo.upsertForDocument(documentId, relations),
        throwsA(isA<StorageConstraintError>()),
      );
    });
  });
}
