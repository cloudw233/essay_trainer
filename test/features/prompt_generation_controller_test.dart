import 'dart:convert';

import 'package:essay_trainer/core/utils/text_similarity.dart';
import 'package:essay_trainer/features/prompt_generation/prompt_generation_controller.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/services/prompt_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Chinese and English similarity detects near-duplicate angles', () {
    final first = similarityTokens('科技与人文的边界 人工智能 医疗');
    final close = similarityTokens('人工智能 医疗 科技与人文的边界');
    final different = similarityTokens('校园 劳动 一次真实的误会');

    expect(jaccardSimilarity(first, close), greaterThan(0.8));
    expect(jaccardSimilarity(first, different), lessThan(0.2));
    expect(
      textSimilarity(
        'Technology and human dignity in a hospital',
        'Human dignity and technology in a hospital',
      ),
      greaterThan(0.5),
    );
  });

  test(
    'third batch receives an automatic new-direction hint after similar batches',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _response(_contentForBatch(calls));
      });
      final controller = PromptGenerationController(
        service: PromptGenerationService(httpClient: client),
      );

      const request = (
        language: EssayLanguage.english,
        genre: EssayGenre.argumentative,
        difficulty: PromptDifficulty.standard,
        key: 'sk-test',
      );

      final first = await controller.generate(
        apiKey: request.key,
        language: request.language,
        genre: request.genre,
        difficulty: request.difficulty,
      );
      expect(first.prompts, hasLength(3));

      await controller.generate(
        apiKey: request.key,
        language: request.language,
        genre: request.genre,
        difficulty: request.difficulty,
      );
      expect(controller.lastBatchWasSimilar, isTrue);

      await controller.generate(
        apiKey: request.key,
        language: request.language,
        genre: request.genre,
        difficulty: request.difficulty,
      );
      expect(calls, 3);
      final thirdUser =
          (bodies.last['messages'] as List<dynamic>).last['content'] as String;
      expect(thirdUser, contains('请完全避开前两批的命题方向'));
      expect(
        (bodies[1]['messages'] as List<dynamic>).last['content'],
        contains('A Shared Topic'),
      );
    },
  );

  test('avoids recent titles and caps the avoid list at ten batches', () async {
    var calls = 0;
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      calls++;
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _response(_contentForBatch(calls));
    });
    final controller = PromptGenerationController(
      service: PromptGenerationService(httpClient: client),
    );

    for (var i = 0; i < 12; i++) {
      await controller.generate(
        apiKey: 'sk-test',
        language: EssayLanguage.english,
        genre: EssayGenre.other,
        difficulty: PromptDifficulty.basic,
      );
    }

    expect(controller.avoidTitles.length, lessThanOrEqualTo(30));
    final lastUser =
        (bodies.last['messages'] as List<dynamic>).last['content'] as String;
    expect(lastUser, contains('avoid_titles'));
  });
}

String _contentForBatch(int batch) {
  final sharedTitle = batch <= 2 ? 'A Shared Topic' : 'A Fresh Angle $batch';
  final sharedRationale = 'A shared technology and dignity debate.';
  final prompts = [
    {
      'title': sharedTitle,
      'promptText': 'Write an essay about technology and dignity. 120 words.',
      'suggestedWordCount': 120,
      'difficulty': 'standard',
      'genre': 'argumentative',
      'rationale': sharedRationale,
    },
    {
      'title': 'A Second Angle $batch',
      'promptText': 'Write an essay about a school decision. 120 words.',
      'suggestedWordCount': 120,
      'difficulty': 'standard',
      'genre': 'argumentative',
      'rationale': sharedRationale,
    },
    {
      'title': 'A Third Angle $batch',
      'promptText': 'Write an essay about a family choice. 120 words.',
      'suggestedWordCount': 120,
      'difficulty': 'standard',
      'genre': 'argumentative',
      'rationale': sharedRationale,
    },
  ];
  return jsonEncode({'prompts': prompts});
}

http.Response _response(String content) {
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
