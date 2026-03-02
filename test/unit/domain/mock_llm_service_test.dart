import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/src/domain/domain.dart';

import '../../mocks/mocks.dart';

void main() {
  group('MockLLMService', () {
    test('summarize returns configured response', () async {
      const inputText = 'This is a long text that needs summarization';
      const expectedSummary = 'This is a summary';

      final mockLLM = MockLLMService(
        summaryResponses: {
          inputText: expectedSummary,
        },
      );

      final result = await mockLLM.summarize(inputText);

      expect(result, equals(expectedSummary));
      expect(mockLLM.summarizeCalls, contains(inputText));
    });

    test('extractKeywords returns configured response', () async {
      const inputText = 'Article about machine learning and AI';
      const expectedKeywords = ['machine learning', 'AI', 'algorithms'];

      final mockLLM = MockLLMService(
        keywordResponses: {
          inputText: expectedKeywords,
        },
      );

      final result = await mockLLM.extractKeywords(inputText);

      expect(result, equals(expectedKeywords));
      expect(mockLLM.extractKeywordsCalls, contains(inputText));
    });

    test('detectPlaces returns configured response', () async {
      const inputText = 'I traveled to Paris and then Berlin';
      final expectedPlaces = [
        const PlacePrediction(placeName: 'Paris', confidence: 0.95),
        const PlacePrediction(placeName: 'Berlin', confidence: 0.92),
      ];

      final mockLLM = MockLLMService(
        placeResponses: {
          inputText: expectedPlaces,
        },
      );

      final result = await mockLLM.detectPlaces(inputText);

      expect(result, equals(expectedPlaces));
      expect(mockLLM.detectPlacesCalls, contains(inputText));
    });

    test('throws StateError for unmapped input when throwMissingResponse is true',
        () async {
      final mockLLM = MockLLMService(throwMissingResponse: true);

      expect(
        () => mockLLM.summarize('unmapped text'),
        throwsA(isA<StateError>()),
      );
    });

    test('returns default response for unmapped input when throwMissingResponse is false',
        () async {
      final mockLLM = MockLLMService(throwMissingResponse: false);

      final result = await mockLLM.summarize('unmapped text');

      expect(result, isNotEmpty);
    });

    test('tracks all operation calls', () async {
      final mockLLM = MockLLMService(
        summaryResponses: {'text1': 'summary1', 'text2': 'summary2'},
        keywordResponses: {'text3': ['kw1', 'kw2']},
        placeResponses: {'text4': []},
      );

      await mockLLM.summarize('text1');
      await mockLLM.summarize('text2');
      await mockLLM.extractKeywords('text3');
      await mockLLM.detectPlaces('text4');
      await mockLLM.detectPlaces('text4');

      final counts = mockLLM.getCallCounts();
      expect(counts.summarizeCalls, equals(2));
      expect(counts.extractKeywordsCalls, equals(1));
      expect(counts.detectPlacesCalls, equals(2));
    });

    test('can reset call tracking', () async {
      final mockLLM = MockLLMService(
        summaryResponses: {'text': 'summary'},
      );

      await mockLLM.summarize('text');
      expect(mockLLM.summarizeCalls, isNotEmpty);

      mockLLM.resetCallTracking();
      expect(mockLLM.summarizeCalls, isEmpty);
    });

    test('throws configured exception', () async {
      final mockLLM = MockLLMService(
        summaryResponses: {'text': 'summary'},
      );

      mockLLM.setException(Exception('LLM error'));

      expect(
        () => mockLLM.summarize('text'),
        throwsA(isA<Exception>()),
      );
    });

    test('simulates processing delay', () async {
      final mockLLM = MockLLMService(
        summaryResponses: {'text': 'summary'},
        simulatedDelay: Duration(milliseconds: 100),
      );

      final stopwatch = Stopwatch()..start();
      await mockLLM.summarize('text');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });
  });
}
