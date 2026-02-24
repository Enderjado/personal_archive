import 'package:personal_archive/src/domain/domain.dart';

/// A per-page response entry for [MockOcrEngine].
class MockOcrResponse {
  const MockOcrResponse({required this.rawText, this.confidence});

  final String rawText;
  final double? confidence;
}

/// Test double for [OCREngine] that returns deterministic, injected
/// [OcrPageResult]s per page index.
///
/// Usage:
/// ```dart
/// final engine = MockOcrEngine(pages: [
///   MockOcrResponse(rawText: 'page one text', confidence: 0.95),
///   MockOcrResponse(rawText: 'page two text', confidence: 0.90),
/// ]);
/// ```
///
/// Calls are matched by call-order: the first call to [extractText] returns
/// [pages[0]], the second returns [pages[1]], etc.  If [throwOnPageIndex] is
/// set, [extractText] throws an [OcrEngineError] when the call count reaches
/// that index (0-based), simulating a mid-run OCR failure.
class MockOcrEngine implements OCREngine {
  MockOcrEngine({
    required this.pages,
    this.throwOnPageIndex,
  });

  /// Per-page deterministic responses, matched by call order.
  final List<MockOcrResponse> pages;

  /// If non-null, [extractText] throws [OcrEngineError] on this call index.
  final int? throwOnPageIndex;

  int _callCount = 0;

  /// The responses that were actually consumed, in call order.
  final List<MockOcrResponse> consumed = [];

  @override
  Future<OcrPageResult> extractText(OcrInput input) async {
    final index = _callCount++;

    if (throwOnPageIndex != null && index == throwOnPageIndex) {
      throw OcrEngineError(
        'MockOcrEngine: simulated failure on page index $index',
      );
    }

    if (index >= pages.length) {
      throw StateError(
        'MockOcrEngine: no response configured for call index $index '
        '(only ${pages.length} page(s) configured)',
      );
    }

    final response = pages[index];
    consumed.add(response);
    return OcrPageResult(rawText: response.rawText, confidence: response.confidence);
  }
}
