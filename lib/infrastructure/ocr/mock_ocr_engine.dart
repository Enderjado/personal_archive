import 'package:personal_archive/src/domain/ocr_engine.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

/// A mock implementation of [OCREngine] for testing purposes.
///
/// This implementation allows tests to control the returned [OcrPageResult]
/// or simulate errors without invoking platform-specific OCR APIs.
class MockOcrEngine implements OCREngine {
  Object? _defaultResponse;
  final List<Object> _responseQueue = [];

  /// Configures the mock to return [result] or throw [error] for all future calls.
  ///
  /// This clears any previously queued responses.
  void setFixedResponse(Object response) {
    _defaultResponse = response;
    _responseQueue.clear();
  }

  /// Queues a specific [result] or [error] to be returned by the next call.
  ///
  /// If multiple responses are queued, they will be processed in order.
  /// If the queue is empty, the response configured via [setFixedResponse] is used.
  void queueResponse(Object response) {
    _responseQueue.add(response);
  }

  @override
  Future<OcrPageResult> extractText(OcrInput input) async {
    final response = _responseQueue.isNotEmpty
        ? _responseQueue.removeAt(0)
        : _defaultResponse;

    if (response is OcrPageResult) {
      return response;
    } else if (response != null) {
      throw response;
    }

    throw UnimplementedError('MockOcrEngine not configured with a response');
  }
}
