import 'dart:convert';

import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/models/essay_draft.dart';
import 'package:essay_trainer/services/grading_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final draft = EssayDraft(
    id: 'draft-1',
    title: 'A Turning Point',
    language: EssayLanguage.english,
    genre: EssayGenre.narrative,
    content: 'The morning was cold and the street was empty.',
    wordCount: 9,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    promptText: 'Write a narrative about a small decision. At least 120 words.',
  );

  Map<String, dynamic> validPayload() => {
    'overallScore': 20,
    'maxScore': 99,
    'dimensionScores': [
      {'name': '内容', 'score': 8, 'maxScore': 10, 'comment': '切题，细节具体。'},
    ],
    'sentenceFeedback': [
      {
        'sentenceIndex': 0,
        'originalText': 'The morning was cold and the street was empty.',
        'issueType': 'praise',
        'severity': 'highlight',
        'comment': '开篇有画面感。',
        'suggestion': 'Keep it.',
      },
      {
        'sentenceIndex': 1,
        'originalText': 'I was very happy.',
        'issueType': 'wordChoice',
        'severity': 'minor',
        'comment': '表达偏泛。',
        'suggestion': 'Use a more specific feeling.',
      },
      {
        'sentenceIndex': 2,
        'originalText': 'Then I go home.',
        'issueType': 'grammar',
        'severity': 'critical',
        'comment': '时态不一致。',
        'suggestion': 'Then I went home.',
      },
    ],
    'paragraphFeedback': [
      {
        'paragraphIndex': 0,
        'coherenceComment': '衔接自然。',
        'contentComment': '有具体情境。',
        'suggestion': '补一个转折细节。',
      },
    ],
    'revisedEssay': 'The morning was cold. The street was empty.',
  };

  test(
    'parses a function-call tool response and injects the requested max score',
    () async {
      Map<String, dynamic>? requestBody;
      final client = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call-1',
                      'type': 'function',
                      'function': {
                        'name': 'submit_grading_report',
                        'arguments': jsonEncode(validPayload()),
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = GradingService(httpClient: client);

      final report = await service.grade(
        apiKey: 'sk-test',
        draft: draft,
        reportId: 'report-1',
        createdAt: DateTime.utc(2026, 1, 2),
      );

      expect(report.id, 'report-1');
      expect(report.overallScore, 20);
      expect(report.maxScore, 25);
      expect(report.sentenceFeedback, hasLength(3));
      expect(
        report.sentenceFeedback.first.severity,
        FeedbackSeverity.highlight,
      );
      expect(report.paragraphFeedback.single.suggestion, '补一个转折细节。');
      expect(report.rawAiResponse, contains('"overallScore"'));

      expect(requestBody, isNotNull);
      expect(requestBody!.containsKey('strict'), isFalse);
      expect(requestBody!['tools'], isA<List<dynamic>>());
      final tools = requestBody!['tools'] as List<dynamic>;
      final tool = tools.single as Map<String, dynamic>;
      expect(
        (tool['function'] as Map<String, dynamic>)['name'],
        'submit_grading_report',
      );
      final messages = requestBody!['messages'] as List<dynamic>;
      expect(messages.first['content'], contains('submit_grading_report'));
      expect(messages.last['content'], contains('At least 120 words'));
    },
  );

  test(
    'retries once when the first tool payload fails schema validation',
    () async {
      var calls = 0;
      final attempts = <int>[];
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          final invalid = validPayload()..remove('revisedEssay');
          return _toolResponse(invalid);
        }
        return _toolResponse(validPayload());
      });
      final service = GradingService(httpClient: client);

      final report = await service.grade(
        apiKey: 'sk-test',
        draft: draft,
        reportId: 'report-2',
        onAttempt: attempts.add,
      );

      expect(report.id, 'report-2');
      expect(calls, 2);
      expect(attempts, [1, 2]);
    },
  );

  test('surfaces raw output after two invalid attempts', () async {
    final client = MockClient(
      (request) async => _toolResponse({'overallScore': 'not-a-number'}),
    );
    final service = GradingService(httpClient: client);

    await expectLater(
      service.grade(apiKey: 'sk-test', draft: draft, reportId: 'report-3'),
      throwsA(
        isA<GradingServiceException>().having(
          (error) => error.rawResponse,
          'rawResponse',
          isNotNull,
        ),
      ),
    );
  });

  test(
    'accepts a content JSON fallback but still validates it strictly',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': jsonEncode(validPayload()),
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final service = GradingService(httpClient: client);

      final report = await service.grade(
        apiKey: 'sk-test',
        draft: draft,
        reportId: 'report-4',
      );
      expect(report.sentenceFeedback, hasLength(3));
    },
  );

  test('maps HTTP 401 to an actionable error', () async {
    final client = MockClient(
      (request) async => http.Response('{"error":{"message":"bad key"}}', 401),
    );
    final service = GradingService(httpClient: client);

    await expectLater(
      service.grade(apiKey: 'sk-bad', draft: draft, reportId: 'report-5'),
      throwsA(
        isA<GradingServiceException>().having(
          (error) => error.message,
          'message',
          contains('API Key'),
        ),
      ),
    );
  });
}

http.Response _toolResponse(Map<String, dynamic> payload) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': 'call-1',
                'type': 'function',
                'function': {
                  'name': 'submit_grading_report',
                  'arguments': jsonEncode(payload),
                },
              },
            ],
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}
