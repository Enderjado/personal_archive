import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/domain/domain.dart';

import 'package:personal_archive/infrastructure/sqlite/documents_fts_sync.dart';
import 'sqlite_storage_integration_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FTS5 integration', () {
    late StorageIntegrationContext ctx;

    setUp(() async {
      ctx = await createStorageIntegrationContext();
    });

    test(
      'happy path: FTS5 search returns matching document',
      () async {
        final now = DateTime.utc(2025, 2, 20, 12, 0, 0);

        // Arrange: create two documents with clearly distinguishable content.
        final docAlpha = Document(
          id: 'fts-doc-alpha',
          title: 'Alpha Document',
          filePath: '/fts/alpha.pdf',
          status: DocumentStatus.completed,
          confidenceScore: 0.9,
          createdAt: now,
          updatedAt: now,
          placeId: null,
        );

        final docBeta = Document(
          id: 'fts-doc-beta',
          title: 'Beta Document',
          filePath: '/fts/beta.pdf',
          status: DocumentStatus.completed,
          confidenceScore: 0.9,
          createdAt: now,
          updatedAt: now,
          placeId: null,
        );

        await ctx.documentRepository.create(docAlpha);
        await ctx.documentRepository.create(docBeta);

        // Add page and summary content so the FTS document has rich text.
        await ctx.pageRepository.insertAll([
          Page(
            id: 'fts-page-alpha-1',
            documentId: docAlpha.id,
            pageNumber: 1,
            rawText: 'alpha raw text',
            processedText: 'alpha unique keyword alphanet',
            ocrConfidence: 0.95,
          ),
          Page(
            id: 'fts-page-beta-1',
            documentId: docBeta.id,
            pageNumber: 1,
            rawText: 'beta raw text',
            processedText: 'beta distinct term betanet',
            ocrConfidence: 0.95,
          ),
        ]);

        final alphaSummary = Summary(
          documentId: docAlpha.id,
          text: 'Summary mentioning alphanet and alpha only.',
          modelVersion: 'fts-test-model',
          createdAt: now,
        );
        await ctx.summaryRepository.upsert(alphaSummary);

        final betaSummary = Summary(
          documentId: docBeta.id,
          text: 'Summary mentioning betanet and beta only.',
          modelVersion: 'fts-test-model',
          createdAt: now,
        );
        await ctx.summaryRepository.upsert(betaSummary);

        // Seed keywords so they are also part of the FTS content.
        final alphaKeyword = await ctx.keywordRepository.getOrCreate(
          'alphanet',
          'topic',
        );
        final betaKeyword = await ctx.keywordRepository.getOrCreate(
          'betanet',
          'topic',
        );

        await ctx.documentKeywordRepository.upsertForDocument(
          docAlpha.id,
          [
            DocumentKeywordRelation(
              id: 'fts-dk-alpha-1',
              documentId: docAlpha.id,
              keywordId: alphaKeyword.id,
              weight: 0.9,
              confidence: 0.9,
              source: 'fts_test',
            ),
          ],
        );

        await ctx.documentKeywordRepository.upsertForDocument(
          docBeta.id,
          [
            DocumentKeywordRelation(
              id: 'fts-dk-beta-1',
              documentId: docBeta.id,
              keywordId: betaKeyword.id,
              weight: 0.9,
              confidence: 0.9,
              source: 'fts_test',
            ),
          ],
        );

        // Act: sync FTS content for both documents using the real sync helper.
        await syncFtsForDocument(ctx.db, docAlpha.id);
        await syncFtsForDocument(ctx.db, docBeta.id);

        // Query the FTS virtual table directly via MigrationDb.
        final rows = await ctx.db.query(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          ['alphanet'],
        );

        final ids = rows.map((row) => row['document_id'] as String).toList();

        // Assert: only the alpha document matches the "alphanet" keyword.
        expect(ids, ['fts-doc-alpha']);
      },
    );

    test(
      'non-matching FTS5 query returns no rows',
      () async {
        final now = DateTime.utc(2025, 2, 20, 13, 0, 0);

        final doc = Document(
          id: 'fts-doc-gamma',
          title: 'Gamma Document',
          filePath: '/fts/gamma.pdf',
          status: DocumentStatus.completed,
          confidenceScore: 0.9,
          createdAt: now,
          updatedAt: now,
          placeId: null,
        );

        await ctx.documentRepository.create(doc);

        await ctx.pageRepository.insertAll([
          Page(
            id: 'fts-page-gamma-1',
            documentId: doc.id,
            pageNumber: 1,
            rawText: 'gamma raw text',
            processedText: 'gamma visible keyword gammanet',
            ocrConfidence: 0.95,
          ),
        ]);

        final summary = Summary(
          documentId: doc.id,
          text: 'Summary mentioning gammanet only.',
          modelVersion: 'fts-test-model',
          createdAt: now,
        );
        await ctx.summaryRepository.upsert(summary);

        final keyword = await ctx.keywordRepository.getOrCreate(
          'gammanet',
          'topic',
        );

        await ctx.documentKeywordRepository.upsertForDocument(
          doc.id,
          [
            DocumentKeywordRelation(
              id: 'fts-dk-gamma-1',
              documentId: doc.id,
              keywordId: keyword.id,
              weight: 0.9,
              confidence: 0.9,
              source: 'fts_test',
            ),
          ],
        );

        await syncFtsForDocument(ctx.db, doc.id);

        final rows = await ctx.db.query(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          ['nonexistentterm'],
        );

        expect(rows, isEmpty);
      },
    );

    test(
      'updating summary content and resyncing FTS updates search results',
      () async {
        final now = DateTime.utc(2025, 2, 20, 14, 0, 0);

        final doc = Document(
          id: 'fts-doc-delta',
          title: 'Delta Document',
          filePath: '/fts/delta.pdf',
          status: DocumentStatus.completed,
          confidenceScore: 0.9,
          createdAt: now,
          updatedAt: now,
          placeId: null,
        );

        await ctx.documentRepository.create(doc);

        // Initial summary mentioning "oldterm" only.
        final initialSummary = Summary(
          documentId: doc.id,
          text: 'Delta summary with oldterm only.',
          modelVersion: 'fts-test-model',
          createdAt: now,
        );
        await ctx.summaryRepository.upsert(initialSummary);

        await syncFtsForDocument(ctx.db, doc.id);

        var rows = await ctx.db.query(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          ['oldterm'],
        );
        expect(
          rows.map((row) => row['document_id'] as String).toList(),
          ['fts-doc-delta'],
        );

        rows = await ctx.db.query(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          ['newterm'],
        );
        expect(rows, isEmpty);

        // Update summary content to remove "oldterm" and include "newterm".
        final updatedSummary = Summary(
          documentId: doc.id,
          text: 'Delta summary with newterm instead.',
          modelVersion: 'fts-test-model',
          createdAt: now,
        );
        await ctx.summaryRepository.upsert(updatedSummary);

        await syncFtsForDocument(ctx.db, doc.id);

        rows = await ctx.db.query(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          ['oldterm'],
        );
        expect(rows, isEmpty);

        rows = await ctx.db.query(
          'SELECT document_id FROM documents_fts WHERE documents_fts MATCH ?',
          ['newterm'],
        );
        expect(
          rows.map((row) => row['document_id'] as String).toList(),
          ['fts-doc-delta'],
        );
      },
    );
  });
}

