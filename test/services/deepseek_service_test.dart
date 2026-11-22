import 'dart:convert';

import 'package:essay_trainer/services/deepseek_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DeepSeekService.testConnection', () {
    test('sends the documented Say OK probe with the bearer key', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.deepseek.com/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer sk-test');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['stream'], isFalse);
        final messages = body['messages'] as List<dynamic>;
        expect(messages.last['role'], 'user');
        expect(messages.last['content'], 'Say OK');

        return http.Response(
          jsonEncode({
            'id': 'chatcmpl-1',
            'created': 0,
            'choices': [
              {
                'index': 0,
                'finish_reason': 'stop',
                'message': {'role': 'assistant', 'content': 'OK'},
              },
            ],
            'usage': {
              'prompt_tokens': 3,
              'completion_tokens': 1,
              'total_tokens': 4,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = DeepSeekService(httpClient: client);
      final reply = await service.testConnection('sk-test');

      expect(reply, 'OK');
    });

    test('turns a 401 into an actionable Chinese message', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Authentication Fails'},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = DeepSeekService(httpClient: client);

      await expectLater(
        service.testConnection('sk-bad'),
        throwsA(
          isA<DeepSeekServiceException>().having(
            (error) => error.message,
            'message',
            contains('API Key'),
          ),
        ),
      );
    });

    test('turns a 429 into a rate-limit message', () async {
      final client = MockClient((request) async {
        return http.Response('rate limited', 429);
      });
      final service = DeepSeekService(httpClient: client);

      await expectLater(
        service.testConnection('sk-test'),
        throwsA(
          isA<DeepSeekServiceException>().having(
            (error) => error.message,
            'message',
            contains('频繁'),
          ),
        ),
      );
    });
  });
}
