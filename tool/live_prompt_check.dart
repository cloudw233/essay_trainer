// ignore_for_file: avoid_print

// Manual live check. Run with a real key, never commit the key:
// DEEPSEEK_API_KEY=... flutter test tool/live_prompt_check.dart
import 'dart:io';

import 'package:essay_trainer/features/prompt_generation/prompt_generation_controller.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/services/prompt_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  test(
    'two live prompt batches avoid exact repeats',
    () async {
      expect(apiKey, isNotNull, reason: 'DEEPSEEK_API_KEY is required');
      final controller = PromptGenerationController(
        service: PromptGenerationService(timeout: const Duration(seconds: 90)),
      );

      final first = await controller.generate(
        apiKey: apiKey!,
        language: EssayLanguage.english,
        genre: EssayGenre.argumentative,
        difficulty: PromptDifficulty.standard,
        onAttempt: (attempt) => print('LIVE_PROMPT_ATTEMPT_1=$attempt'),
      );
      print('LIVE_PROMPT_BATCH_1=${first.prompts.length}');
      for (final prompt in first.prompts) {
        print('LIVE_PROMPT_1 ${prompt.title}');
      }

      final second = await controller.generate(
        apiKey: apiKey,
        language: EssayLanguage.english,
        genre: EssayGenre.argumentative,
        difficulty: PromptDifficulty.standard,
        onAttempt: (attempt) => print('LIVE_PROMPT_ATTEMPT_2=$attempt'),
      );
      print('LIVE_PROMPT_BATCH_2=${second.prompts.length}');
      for (final prompt in second.prompts) {
        print('LIVE_PROMPT_2 ${prompt.title}');
      }

      final firstTitles = first.prompts.map((p) => p.title.trim()).toSet();
      final secondTitles = second.prompts.map((p) => p.title.trim()).toSet();
      print(
        'LIVE_PROMPT_OVERLAP='
        '${firstTitles.intersection(secondTitles).length}',
      );
      print('LIVE_PROMPT_SIMILAR=${controller.lastBatchWasSimilar}');
      expect(first.prompts, hasLength(3));
      expect(second.prompts, hasLength(3));
      expect(firstTitles.intersection(secondTitles), isEmpty);
      for (final prompt in [...first.prompts, ...second.prompts]) {
        expect(prompt.promptText.trim(), isNotEmpty);
        expect(prompt.suggestedWordCount, greaterThan(0));
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
