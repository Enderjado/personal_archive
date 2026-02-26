import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/application/application.dart';
import 'package:personal_archive/src/domain/domain.dart';

void main() {
  group('OcrTextProcessor', () {
    // Default instance with no header/footer patterns.
    const processor = OcrTextProcessor();

    // -------------------------------------------------------------------------
    // Empty / near-empty input
    // -------------------------------------------------------------------------

    group('empty and near-empty input', () {
      test('returns empty string for empty input', () {
        expect(processor.clean(''), '');
      });

      test('returns empty string for whitespace-only input', () {
        expect(processor.clean('   \n\t\n  '), '');
      });

      test('returns the word for a single-word input', () {
        expect(processor.clean('hello'), 'hello');
      });
    });

    // -------------------------------------------------------------------------
    // Pass 1 – whitespace and line-break normalisation
    // -------------------------------------------------------------------------

    group('whitespace normalisation', () {
      test('collapses multiple spaces to one', () {
        expect(processor.clean('too   many    spaces'), 'too many spaces');
      });

      test('collapses tabs mixed with spaces to one space', () {
        expect(processor.clean('col1\t\t  col2'), 'col1 col2');
      });

      test('trims leading and trailing whitespace', () {
        expect(processor.clean('  trimmed  '), 'trimmed');
      });

      test('normalises CRLF line endings to LF', () {
        const input = 'line one\r\nline two\r\nline three';
        const expected = 'line one\nline two\nline three';
        expect(processor.clean(input), expected);
      });

      test('normalises CR-only line endings to LF', () {
        const input = 'line one\rline two';
        const expected = 'line one\nline two';
        expect(processor.clean(input), expected);
      });

      test('trims leading/trailing spaces from every line', () {
        const input = '  first line  \n  second line  ';
        const expected = 'first line\nsecond line';
        expect(processor.clean(input), expected);
      });

      test('collapses three or more blank lines to two', () {
        const input = 'para one\n\n\n\npara two';
        const expected = 'para one\n\npara two';
        expect(processor.clean(input), expected);
      });

      test('preserves intentional double newline paragraph breaks', () {
        const input = 'first paragraph\n\nsecond paragraph';
        expect(processor.clean(input), 'first paragraph\n\nsecond paragraph');
      });
    });

    // -------------------------------------------------------------------------
    // Pass 2 – hyphenation rejoining
    // -------------------------------------------------------------------------

    group('hyphenation rejoining', () {
      test('rejoins word split by hyphen + newline', () {
        const input = 'recogni-\ntion is key';
        expect(processor.clean(input), 'recognition is key');
      });

      test('rejoins multiple hyphenations on the same page', () {
        const input = 'back-\nground and fore-\nground';
        expect(processor.clean(input), 'background and foreground');
      });

      test('does not remove hyphen inside a line (compound word)', () {
        // "well-known" on a single line should stay intact.
        expect(processor.clean('well-known'), 'well-known');
      });

      test('does not trigger on digit-hyphen-newline', () {
        // "10-\nnm" – digits are not letters; expect hyphen to stay.
        const input = '10-\nnm resolution';
        expect(processor.clean(input), '10-\nnm resolution');
      });
    });

    // -------------------------------------------------------------------------
    // Pass 3 – header/footer stripping
    // -------------------------------------------------------------------------

    group('header and footer stripping', () {
      test('removes lines that exactly match a header pattern', () {
        const proc = OcrTextProcessor(
          config: TextProcessingConfig(
            headerPatterns: [r'DOCUMENT TITLE'],
          ),
        );
        const input = 'DOCUMENT TITLE\nSome actual content.\nMore content.';
        expect(proc.clean(input), 'Some actual content.\nMore content.');
      });

      test('removes lines matching footer pattern', () {
        const proc = OcrTextProcessor(
          config: TextProcessingConfig(
            footerPatterns: [r'Page \d+ of \d+'],
          ),
        );
        const input = 'Body text.\nPage 3 of 10';
        expect(proc.clean(input), 'Body text.');
      });

      test('removes both header and footer patterns', () {
        const proc = OcrTextProcessor(
          config: TextProcessingConfig(
            headerPatterns: [r'CONFIDENTIAL'],
            footerPatterns: [r'Page \d+'],
          ),
        );
        const input = 'CONFIDENTIAL\nActual content.\nPage 7';
        expect(proc.clean(input), 'Actual content.');
      });

      test('does not strip partial-line matches', () {
        const proc = OcrTextProcessor(
          config: TextProcessingConfig(
            headerPatterns: [r'TITLE'],
          ),
        );
        // "TITLE" is embedded in sentence – full-line match should not trigger.
        const input = 'The TITLE of the document is important.';
        expect(proc.clean(input), 'The TITLE of the document is important.');
      });

      test('no-op when pattern list is empty', () {
        const input = 'Line one.\nLine two.';
        expect(processor.clean(input), 'Line one.\nLine two.');
      });
    });

    // -------------------------------------------------------------------------
    // Combined OCR noise scenarios
    // -------------------------------------------------------------------------

    group('combined OCR noise', () {
      test('handles a realistic noisy OCR page', () {
        const proc = OcrTextProcessor(
          config: TextProcessingConfig(
            headerPatterns: [r'Annual Report 2024'],
            footerPatterns: [r'Page \d+ of \d+'],
          ),
        );
        const input = 'Annual Report 2024\r\n'
            'This is   the first   para-\n'
            'graph of the   document.\r\n'
            '\r\n'
            '\r\n'
            'Second paragraph  here.\r\n'
            'Page 1 of 5';
        const expected = 'This is the first paragraph of the document.\n\n'
            'Second paragraph here.';
        expect(proc.clean(input), expected);
      });
    });
  });
}
