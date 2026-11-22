import 'dart:convert';

import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/services/prompt_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PromptGenerationService', () {
    test('requests JSON mode and validates three candidates', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        return _success(_validContent());
      });
      final service = PromptGenerationService(httpClient: client);

      final batch = await service.generate(
        apiKey: 'sk-test',
        request: const PromptGenerationRequest(
          language: EssayLanguage.english,
          genre: EssayGenre.argumentative,
          difficulty: PromptDifficulty.standard,
          avoidTitles: ['Old prompt'],
          extraHint: 'school life',
        ),
      );

      expect(batch.prompts, hasLength(3));
      expect(batch.attempts, 1);
      expect(bodies, hasLength(1));
      expect(bodies.single['response_format'], {'type': 'json_object'});
      expect(bodies.single.containsKey('strict'), isFalse);
      expect(bodies.single['tools'], isNull);

      final messages = bodies.single['messages'] as List<dynamic>;
      expect(messages.first['role'], 'system');
      expect(messages.last['role'], 'user');
      expect(messages.last['content'], contains('avoid_titles'));
      expect(messages.last['content'], contains('Old prompt'));
    });

    test('retries exactly once after a schema validation failure', () async {
      var calls = 0;
      final attempts = <int>[];
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        calls++;
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (calls == 1) {
          return _success(
            jsonEncode({
              'prompts': [
                {
                  'title': 'Only one',
                  'promptText': 'Write a speech.',
                  'suggestedWordCount': 120,
                  'difficulty': 'standard',
                  'genre': 'application',
                  'rationale': 'Too few candidates.',
                },
              ],
            }),
          );
        }
        return _success(_validContent());
      });
      final service = PromptGenerationService(httpClient: client);

      final batch = await service.generate(
        apiKey: 'sk-test',
        request: const PromptGenerationRequest(
          language: EssayLanguage.english,
          genre: EssayGenre.application,
          difficulty: PromptDifficulty.standard,
        ),
        onAttempt: attempts.add,
      );

      expect(batch.attempts, 2);
      expect(calls, 2);
      expect(attempts, [1, 2]);
      final retryUserMessage =
          (bodies[1]['messages'] as List<dynamic>).last['content'] as String;
      expect(retryUserMessage, contains('上一次输出未通过格式校验'));
      expect(retryUserMessage, contains('字段名和类型必须完全一致'));
    });

    test('does not silently accept a batch that fails twice', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _success(jsonEncode({'prompts': []}));
      });
      final service = PromptGenerationService(httpClient: client);

      await expectLater(
        service.generate(
          apiKey: 'sk-test',
          request: const PromptGenerationRequest(
            language: EssayLanguage.chinese,
            genre: EssayGenre.narrative,
            difficulty: PromptDifficulty.basic,
          ),
        ),
        throwsA(isA<PromptGenerationException>()),
      );
      expect(calls, 2);
    });

    test('maps an auth failure to an actionable message', () async {
      final client = MockClient(
        (request) async =>
            http.Response('{"error":{"message":"bad key"}}', 401),
      );
      final service = PromptGenerationService(httpClient: client);

      await expectLater(
        service.generate(
          apiKey: 'sk-bad',
          request: const PromptGenerationRequest(
            language: EssayLanguage.chinese,
            genre: EssayGenre.other,
            difficulty: PromptDifficulty.standard,
          ),
        ),
        throwsA(
          isA<PromptGenerationException>().having(
            (error) => error.message,
            'message',
            contains('API Key'),
          ),
        ),
      );
    });
  });
}

String _validContent() {
  final prompts = [
    {
      'title': 'A Letter to the School Library',
      'promptText':
          'Your school library will change its opening hours. Write a letter to the librarian explaining the needs of students and suggesting one change. Write at least 120 words. Use the letter format.',
      'suggestedWordCount': 120,
      'difficulty': 'standard',
      'genre': 'application',
      'rationale': 'Tests purposeful application writing with a real audience.',
    },
    {
      'title': 'The Empty Seat',
      'promptText':
          'A new student sits alone at lunch. Write a narrative about a small decision someone makes that day. Write at least 150 words.',
      'suggestedWordCount': 150,
      'difficulty': 'standard',
      'genre': 'narrative',
      'rationale': 'Tests concrete experience and a meaningful turning point.',
    },
    {
      'title': 'A Choice Between Two Good Things',
      'promptText':
          'Write an argumentative essay about a student who must choose between joining a competition and helping a friend prepare for an exam. State your position and support it with reasons. Write at least 150 words.',
      'suggestedWordCount': 150,
      'difficulty': 'standard',
      'genre': 'argumentative',
      'rationale': 'Tests reasoning under a genuine value tension.',
    },
  ];
  return jsonEncode({'prompts': prompts});
}

http.Response _success(String content) {
  return http.Response(
    jsonEncode({
      'id': 'chatcmpl-test',
      'created': 0,
      'choices': [
        {
          'index': 0,
          'finish_reason': 'stop',
          'message': {'role': 'assistant', 'content': content},
        },
      ],
      'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}
