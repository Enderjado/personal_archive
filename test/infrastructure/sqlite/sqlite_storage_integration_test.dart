import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/domain/domain.dart';

import 'sqlite_storage_integration_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage integration end-to-end', () {
    late StorageIntegrationContext ctx;

    setUp(() async {
      ctx = await createStorageIntegrationContext();
    });

    test(
      'full flow: document + place + pages + summary + keywords + embedding round-trip',
      () async {
        // Arrange: create a place.
        final place = await ctx.placeRepository.getOrCreate('Archive');
        final now = DateTime.utc(2025, 2, 19, 12, 0, 0);

        // Document referencing the place.
        final document = Document(
          id: 'e2e-doc-1',
          title: 'End-to-End Storage Doc',
          filePath: '/path/e2e.pdf',
          status: DocumentStatus.completed,
          confidenceScore: 0.95,
          createdAt: now,
          updatedAt: now,
          placeId: place.id,
        );
        await ctx.documentRepository.create(document);

        // Pages for the document.
        final pages = <Page>[
          Page(
            id: 'e2e-page-1',
            documentId: document.id,
            pageNumber: 1,
            rawText: 'raw one',
            processedText: 'processed one',
            ocrConfidence: 0.9,
          ),
          Page(
            id: 'e2e-page-2',
            documentId: document.id,
            pageNumber: 2,
            rawText: 'raw two',
            processedText: 'processed two',
            ocrConfidence: 0.88,
          ),
        ];
        await ctx.pageRepository.insertAll(pages);

        // Summary for the document.
        final summary = Summary(
          documentId: document.id,
          text: 'A concise summary of the document.',
          modelVersion: 'qwen2.5-0.5b',
          createdAt: now,
        );
        await ctx.summaryRepository.upsert(summary);

        // Keywords and document-keyword relations.
        final topicKeyword =
            await ctx.keywordRepository.getOrCreate('taxes', 'topic');
        final yearKeyword =
            await ctx.keywordRepository.getOrCreate('2024', 'date');

        final relations = <DocumentKeywordRelation>[
          DocumentKeywordRelation(
            id: 'e2e-dk-1',
            documentId: document.id,
            keywordId: topicKeyword.id,
            weight: 0.8,
            confidence: 0.9,
            source: 'llm_initial',
          ),
          DocumentKeywordRelation(
            id: 'e2e-dk-2',
            documentId: document.id,
            keywordId: yearKeyword.id,
            weight: 0.6,
            confidence: 0.85,
            source: 'llm_initial',
          ),
        ];
        await ctx.documentKeywordRepository.upsertForDocument(
          document.id,
          relations,
        );

        // Embedding for the document.
        final embedding = Embedding(
          documentId: document.id,
          vector: <double>[0.1, -0.2, 0.3],
          modelVersion: 'embed-model-v1',
          createdAt: now,
        );
        await ctx.embeddingRepository.upsert(embedding);

        // Act: read data back through repositories.
        final foundDoc = await ctx.documentRepository.findById(document.id);
        final foundPages =
            await ctx.pageRepository.findByDocumentId(document.id);
        final foundSummary =
            await ctx.summaryRepository.findByDocumentId(document.id);
        final foundKeywords =
            await ctx.documentKeywordRepository.listForDocument(document.id);
        final foundEmbedding =
            await ctx.embeddingRepository.findByDocumentId(document.id);

        // Assert: document + place link.
        expect(foundDoc, isNotNull);
        expect(foundDoc!.id, document.id);
        expect(foundDoc.title, document.title);
        expect(foundDoc.placeId, place.id);
        expect(foundDoc.status, DocumentStatus.completed);
        expect(foundDoc.confidenceScore, closeTo(0.95, 1e-9));

        // Assert: pages are round-tripped in order.
        expect(foundPages, hasLength(2));
        expect(foundPages.first.pageNumber, 1);
        expect(foundPages.last.pageNumber, 2);
        expect(foundPages.first.processedText, 'processed one');
        expect(foundPages.last.processedText, 'processed two');

        // Assert: summary is present and matches.
        expect(foundSummary, isNotNull);
        expect(foundSummary!.documentId, document.id);
        expect(foundSummary.text, summary.text);
        expect(foundSummary.modelVersion, summary.modelVersion);

        // Assert: keywords returned for the document.
        final keywordValues = foundKeywords.map((k) => k.value).toSet();
        expect(keywordValues, {'taxes', '2024'});

        // Assert: embedding round-trips.
        expect(foundEmbedding, isNotNull);
        expect(foundEmbedding!.documentId, document.id);
        expect(foundEmbedding.vector, <double>[0.1, -0.2, 0.3]);
        expect(foundEmbedding.modelVersion, 'embed-model-v1');
      },
    );

    test(
      'documents can be filtered by status, place, and createdAt range',
      () async {
        final base = DateTime.utc(2025, 2, 19, 10, 0, 0);

        // Two places.
        final inbox = await ctx.placeRepository.getOrCreate('Inbox');
        final archive = await ctx.placeRepository.getOrCreate('Archive');

        // Seed documents with different status, place, and createdAt values.
        final docs = <Document>[
          Document(
            id: 'filter-doc-1',
            title: 'Imported in Inbox (old)',
            filePath: '/docs/1.pdf',
            status: DocumentStatus.imported,
            createdAt: base.subtract(const Duration(days: 2)),
            updatedAt: base.subtract(const Duration(days: 2)),
            placeId: inbox.id,
          ),
          Document(
            id: 'filter-doc-2',
            title: 'Imported in Inbox (mid)',
            filePath: '/docs/2.pdf',
            status: DocumentStatus.imported,
            createdAt: base,
            updatedAt: base,
            placeId: inbox.id,
          ),
          Document(
            id: 'filter-doc-3',
            title: 'Completed in Archive (mid)',
            filePath: '/docs/3.pdf',
            status: DocumentStatus.completed,
            createdAt: base,
            updatedAt: base,
            placeId: archive.id,
          ),
          Document(
            id: 'filter-doc-4',
            title: 'Completed in Archive (future)',
            filePath: '/docs/4.pdf',
            status: DocumentStatus.completed,
            createdAt: base.add(const Duration(days: 2)),
            updatedAt: base.add(const Duration(days: 2)),
            placeId: archive.id,
          ),
        ];

        for (final d in docs) {
          await ctx.documentRepository.create(d);
        }

        // 1) Filter by status only.
        final importedOnly =
            await ctx.documentRepository.list(status: DocumentStatus.imported);
        final importedIds = importedOnly.map((d) => d.id).toSet();
        expect(importedIds, {'filter-doc-1', 'filter-doc-2'});

        // 2) Filter by place only.
        final archiveOnly =
            await ctx.documentRepository.list(placeId: archive.id);
        final archiveIds = archiveOnly.map((d) => d.id).toSet();
        expect(archiveIds, {'filter-doc-3', 'filter-doc-4'});

        // 3) Combined filter: completed, at Archive, within a time window.
        final range = DateTimeRange(
          start: base.subtract(const Duration(hours: 1)),
          end: base.add(const Duration(hours: 1)),
        );
        final completedArchiveMid = await ctx.documentRepository.list(
          status: DocumentStatus.completed,
          placeId: archive.id,
          createdBetween: range,
        );
        final completedArchiveMidIds =
            completedArchiveMid.map((d) => d.id).toList();
        expect(completedArchiveMidIds, ['filter-doc-3']);
      },
    );

    test(
      'summary upsert fails for non-existent documentId (FK constraint)',
      () async {
        final now = DateTime.utc(2025, 2, 19, 15, 0, 0);
        final summary = Summary(
          documentId: 'missing-doc-id',
          text: 'Should not be stored',
          modelVersion: 'qwen2.5-0.5b',
          createdAt: now,
        );

        expect(
          () => ctx.summaryRepository.upsert(summary),
          throwsA(isA<StorageConstraintError>()),
        );
      },
    );
  });
}

