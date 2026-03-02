import 'package:personal_archive/src/domain/domain.dart';

/// Holds the call count statistics for mock LLM operations.
class LLMServiceCallCounts {
  /// Number of times [LLMService.summarize] was called.
  final int summarizeCalls;

  /// Number of times [LLMService.extractKeywords] was called.
  final int extractKeywordsCalls;

  /// Number of times [LLMService.detectPlaces] was called.
  final int detectPlacesCalls;

  /// Creates call count statistics.
  const LLMServiceCallCounts({
    required this.summarizeCalls,
    required this.extractKeywordsCalls,
    required this.detectPlacesCalls,
  });

  @override
  String toString() =>
      'LLMServiceCallCounts(summarizeCalls: $summarizeCalls, extractKeywordsCalls: $extractKeywordsCalls, detectPlacesCalls: $detectPlacesCalls)';
}

/// Mock implementation of [LLMService] for unit testing.
///
/// Provides deterministic, customizable responses for all LLM operations.
/// Useful for testing Intelligence features without depending on the actual
/// llama.cpp runtime.
///
/// **Features:**
/// - Synchronous in behavior (though still `Future`-returning)
/// - Fully customizable responses per operation
/// - Optional built-in delay simulation for testing async behavior
/// - Tracks call count and arguments for verifying test expectations
///
/// **Typical Usage:**
/// ```dart
/// final mockLLM = MockLLMService(
///   summaryResponses: {
///     'input text': 'output summary',
///   },
/// );
///
/// expect(
///   mockLLM.summarize('input text'),
///   completion(equals('output summary')),
/// );
/// ```
class MockLLMService implements LLMService {
  /// Predefined summary responses mapped by input text.
  ///
  /// If a text is provided that's not in this map, the mock will either
  /// throw (if [throwMissingResponse] is true) or return a default response.
  final Map<String, String> summaryResponses;

  /// Predefined keyword extraction responses mapped by input text.
  final Map<String, List<String>> keywordResponses;

  /// Predefined place detection responses mapped by input text.
  final Map<String, List<PlacePrediction>> placeResponses;

  /// Optional artificial delay to simulate real LLM processing time.
  final Duration? simulatedDelay;

  /// If true, throws [StateError] when an unmapped input is requested.
  /// If false, returns default empty responses for unmapped inputs.
  final bool throwMissingResponse;

  /// Tracks all summarize() calls with their input text.
  final List<String> summarizeCalls = [];

  /// Tracks all extractKeywords() calls with their input text.
  final List<String> extractKeywordsCalls = [];

  /// Tracks all detectPlaces() calls with their input text.
  final List<String> detectPlacesCalls = [];

  /// Optional exception to throw for all operations (for error testing).
  Exception? _exceptionToThrow;

  /// Creates a mock LLMService.
  ///
  /// [summaryResponses] - Map of input text to expected summary output.
  /// [keywordResponses] - Map of input text to expected keyword lists.
  /// [placeResponses] - Map of input text to expected place predictions.
  /// [simulatedDelay] - Optional delay to add to all operations.
  /// [throwMissingResponse] - Whether to throw for unmapped inputs (default: true).
  MockLLMService({
    this.summaryResponses = const {},
    this.keywordResponses = const {},
    this.placeResponses = const {},
    this.simulatedDelay,
    this.throwMissingResponse = true,
  });

  /// Sets an exception that will be thrown by all operations until cleared.
  ///
  /// Useful for testing error handling in dependent code.
  void setException(Exception exception) {
    _exceptionToThrow = exception;
  }

  /// Clears any exception set via [setException].
  void clearException() {
    _exceptionToThrow = null;
  }

  /// Resets all call tracking lists.
  void resetCallTracking() {
    summarizeCalls.clear();
    extractKeywordsCalls.clear();
    detectPlacesCalls.clear();
  }

  /// Returns the number of times each operation was called.
  LLMServiceCallCounts getCallCounts() => LLMServiceCallCounts(
        summarizeCalls: this.summarizeCalls.length,
        extractKeywordsCalls: this.extractKeywordsCalls.length,
        detectPlacesCalls: this.detectPlacesCalls.length,
      );

  @override
  Future<String> summarize(String text) async {
    summarizeCalls.add(text);

    if (_exceptionToThrow != null) {
      throw _exceptionToThrow!;
    }

    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }

    if (summaryResponses.containsKey(text)) {
      return summaryResponses[text]!;
    }

    if (throwMissingResponse) {
      throw StateError(
        'MockLLMService: No summary response configured for text: "$text"',
      );
    }

    return 'Mock summary of: ${text.substring(0, (text.length ~/ 2).clamp(0, 50))}...';
  }

  @override
  Future<List<String>> extractKeywords(String text) async {
    extractKeywordsCalls.add(text);

    if (_exceptionToThrow != null) {
      throw _exceptionToThrow!;
    }

    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }

    if (keywordResponses.containsKey(text)) {
      return keywordResponses[text]!;
    }

    if (throwMissingResponse) {
      throw StateError(
        'MockLLMService: No keyword response configured for text: "$text"',
      );
    }

    return ['keyword', 'term', 'concept'];
  }

  @override
  Future<List<PlacePrediction>> detectPlaces(String text) async {
    detectPlacesCalls.add(text);

    if (_exceptionToThrow != null) {
      throw _exceptionToThrow!;
    }

    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }

    if (placeResponses.containsKey(text)) {
      return placeResponses[text]!;
    }

    if (throwMissingResponse) {
      throw StateError(
        'MockLLMService: No place response configured for text: "$text"',
      );
    }

    return [];
  }
}
