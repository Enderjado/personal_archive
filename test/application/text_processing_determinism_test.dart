import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/application/application.dart';
import 'package:personal_archive/src/domain/domain.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _docId = 'doc-determinism';

/// Calls [fn] [times] times and asserts every result equals the first.
void _assertDeterministic<T>(T Function() fn, {int times = 5}) {
  final first = fn();
  for (var i = 1; i < times; i++) {
    final result = fn();
    expect(result, equals(first),
        reason: 'Call $i produced a different result than call 0.');
  }
}

/// Deep-equality check for two [TextChunk] lists.
Matcher _chunkListEquals(List<TextChunk> expected) =>
    equals(expected.map(_chunkMatcher).toList());

Matcher _chunkMatcher(TextChunk c) =>
    isA<TextChunk>()
        .having((x) => x.documentId, 'documentId', c.documentId)
        .having((x) => x.text, 'text', c.text)
        .having((x) => x.tokenCount, 'tokenCount', c.tokenCount)
        .having((x) => x.pageNumber, 'pageNumber', c.pageNumber);

void main() {
  group('Determinism – OcrTextProcessor.clean', () {
    // -------------------------------------------------------------------------
    // Determinism across repeated calls (same instance)
    // -------------------------------------------------------------------------

    test('empty input is always empty', () {
      const p = OcrTextProcessor();
      _assertDeterministic(() => p.clean(''));
    });

    test('whitespace-only input always yields empty string', () {
      const p = OcrTextProcessor();
      _assertDeterministic(() => p.clean('  \n\t\n  '));
    });

    test('simple sentence is stable across calls', () {
      const p = OcrTextProcessor();
      const input = 'The   quick  brown   fox.';
      _assertDeterministic(() => p.clean(input));
    });

    test('OCR noise with CRLF and hyphenation is stable', () {
      const p = OcrTextProcessor();
      const input = 'First  line\r\nSecond   line with recogni-\ntion.\r\n\r\n'
          'Paragraph  two.';
      _assertDeterministic(() => p.clean(input));
    });

    test('same result from two independent instances with same config', () {
      const config = TextProcessingConfig(
        headerPatterns: [r'HEADER'],
        footerPatterns: [r'Page \d+'],
      );
      const p1 = OcrTextProcessor(config: config);
      const p2 = OcrTextProcessor(config: config);
      const input = 'HEADER\nBody text.\nPage 3';
      expect(p1.clean(input), equals(p2.clean(input)));
    });

    test('header/footer stripping is stable across repeated calls', () {
      const p = OcrTextProcessor(
        config: TextProcessingConfig(
          headerPatterns: [r'CONFIDENTIAL'],
          footerPatterns: [r'Page \d+ of \d+'],
        ),
      );
      const input = 'CONFIDENTIAL\nReal content here.\nPage 2 of 10';
      _assertDeterministic(() => p.clean(input));
    });

    test('long page with all noise types is stable', () {
      const p = OcrTextProcessor(
        config: TextProcessingConfig(
          headerPatterns: [r'Annual Report'],
          footerPatterns: [r'\d+'],
        ),
      );
      const input = 'Annual Report\r\n'
          'This is   the first para-\ngraph.\r\n'
          '\r\n'
          '\r\n'
          '\r\n'
          'Second  paragraph  here.\r\n'
          '42';
      _assertDeterministic(() => p.clean(input));
    });
  });

  // ---------------------------------------------------------------------------

  group('Determinism – ParagraphChunker.chunk', () {
    test('empty input always yields empty list', () {
      const chunker = ParagraphChunker();
      _assertDeterministic(
        () => chunker.chunk('', documentId: _docId),
      );
    });

    test('single short sentence always yields one identical chunk', () {
      const chunker = ParagraphChunker();
      const input = 'A single short sentence.';
      _assertDeterministic(
        () => chunker.chunk(input, documentId: _docId),
      );
    });

    test('multi-paragraph input produces stable chunk list', () {
      const chunker = ParagraphChunker(
        config: ChunkingConfig(
          maxTokensPerChunk: 20,
          minTokensPerChunk: 3,
          overlapFraction: 0.1,
        ),
      );
      final input = List.generate(
        6,
        (i) => 'Paragraph $i with some content words to fill it up nicely.',
      ).join('\n\n');

      _assertDeterministic(
        () => chunker.chunk(input, documentId: _docId),
      );
    });

    test('over-budget single paragraph splits stably', () {
      const chunker = ParagraphChunker(
        config: ChunkingConfig(
          maxTokensPerChunk: 10,
          minTokensPerChunk: 1,
          overlapFraction: 0,
        ),
      );
      final input = List.generate(40, (i) => 'word$i').join(' ');
      _assertDeterministic(
        () => chunker.chunk(input, documentId: _docId),
      );
    });

    test('two independent chunker instances with same config produce equal results', () {
      const config = ChunkingConfig(
        maxTokensPerChunk: 15,
        minTokensPerChunk: 2,
        overlapFraction: 0.1,
      );
      const c1 = ParagraphChunker(config: config);
      const c2 = ParagraphChunker(config: config);
      const input =
          'First paragraph with enough words.\n\nSecond paragraph here.';
      final result1 = c1.chunk(input, documentId: _docId);
      final result2 = c2.chunk(input, documentId: _docId);
      expect(result1, _chunkListEquals(result2));
    });

    test('pageNumber is propagated identically on repeated calls', () {
      const chunker = ParagraphChunker();
      const input = 'Some text on page seven.';
      _assertDeterministic(
        () => chunker.chunk(input, documentId: _docId, pageNumber: 7),
      );
    });

    test('chunk tokenCounts are identical across repeated calls', () {
      const chunker = ParagraphChunker(
        config: ChunkingConfig(
          maxTokensPerChunk: 20,
          minTokensPerChunk: 2,
          overlapFraction: 0.1,
        ),
      );
      final input = List.generate(
        4,
        (i) => 'Para $i: some words to reach a reasonable token count.',
      ).join('\n\n');

      final first = chunker.chunk(input, documentId: _docId);
      for (var i = 0; i < 4; i++) {
        final repeat = chunker.chunk(input, documentId: _docId);
        final firstTokens = first.map((c) => c.tokenCount).toList();
        final repeatTokens = repeat.map((c) => c.tokenCount).toList();
        expect(repeatTokens, equals(firstTokens),
            reason: 'tokenCounts differed on iteration $i');
      }
    });
  });

  // ---------------------------------------------------------------------------

  group('Determinism – processor then chunker pipeline', () {
    test('same raw input produces same final chunks end-to-end', () {
      const processor = OcrTextProcessor(
        config: TextProcessingConfig(
          headerPatterns: [r'REPORT'],
          footerPatterns: [r'Page \d+'],
        ),
      );
      const chunker = ParagraphChunker(
        config: ChunkingConfig(
          maxTokensPerChunk: 30,
          minTokensPerChunk: 3,
          overlapFraction: 0.1,
        ),
      );
      const raw = 'REPORT\r\n'
          'First para-\ngraph content.\r\n'
          '\r\n'
          'Second paragraph content.\r\n'
          'Page 1';

      List<TextChunk> run() {
        final cleaned = processor.clean(raw);
        return chunker.chunk(cleaned, documentId: _docId, pageNumber: 1);
      }

      _assertDeterministic(run);
    });
  });
}
