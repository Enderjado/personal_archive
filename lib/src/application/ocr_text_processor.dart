import '../domain/text_processor.dart';

/// A concrete [TextProcessor] that cleans raw OCR output in multiple passes.
///
/// Each pass targets a specific class of noise. Passes are applied in order:
/// 1. Whitespace and line-break normalisation (always active).
///
/// This class is pure and stateless; the same input always yields the same
/// output, making it straightforward to test and safe to cache.
class OcrTextProcessor implements TextProcessor {
  const OcrTextProcessor();

  @override
  String clean(String raw) {
    if (raw.trim().isEmpty) return '';

    var text = raw;
    text = _normaliseLineEndings(text);
    text = _normaliseWhitespace(text);
    text = _trimLines(text);
    text = _collapseBlankLines(text);
    return text.trim();
  }

  // ---------------------------------------------------------------------------
  // Pass 1 – whitespace and line-break normalisation
  // ---------------------------------------------------------------------------

  /// Converts all CRLF and CR line endings to a single LF.
  String _normaliseLineEndings(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// Collapses runs of horizontal whitespace (spaces, tabs) to a single space
  /// on each line, preserving line breaks.
  String _normaliseWhitespace(String text) {
    // Replace each run of horizontal whitespace with one space.
    return text.replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  /// Removes leading and trailing spaces from every line.
  String _trimLines(String text) {
    return text.split('\n').map((line) => line.trim()).join('\n');
  }

  /// Collapses runs of more than two consecutive blank lines into two,
  /// preserving intentional paragraph breaks.
  String _collapseBlankLines(String text) {
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
}
