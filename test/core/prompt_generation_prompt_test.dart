import 'package:essay_trainer/core/prompts/prompt_generation.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chinese generation prompt contains the quality gates and schema', () {
    final prompt = PromptGenerationPromptBuilder.systemPrompt(
      EssayLanguage.chinese,
    );

    expect(prompt, contains('命题人'));
    expect(prompt, contains('avoid_titles'));
    expect(prompt, contains('extra_hint'));
    expect(prompt, contains('论坚持'));
    expect(prompt, contains('科技改变生活'));
    expect(prompt, contains('json_object'));
    expect(prompt, contains('promptText'));
    expect(prompt, contains('suggestedWordCount'));
    expect(prompt, contains('rationale'));
    expect(prompt, contains('只输出这个 JSON 对象'));
    expect(prompt, isNot(contains('"strict"')));
  });

  test('English generation prompt contains authentic discourse types', () {
    final prompt = PromptGenerationPromptBuilder.systemPrompt(
      EssayLanguage.english,
    );

    expect(prompt, contains('experienced'));
    expect(prompt, contains('avoid_titles'));
    expect(prompt, contains('extra_hint'));
    expect(prompt, contains('The Importance of Persistence'));
    expect(prompt, contains('json_object'));
    expect(prompt, contains('promptText'));
    expect(prompt, contains('suggestedWordCount'));
    expect(prompt, contains('letter'));
    expect(prompt, contains('speech'));
    expect(prompt, contains('Only output this JSON object'));
    expect(prompt, isNot(contains('"strict"')));
  });

  test('user message carries parameters instead of hardcoding them', () {
    final prompt = PromptGenerationPromptBuilder.userPrompt(
      language: EssayLanguage.english,
      genre: EssayGenre.argumentative,
      difficulty: PromptDifficulty.challenging,
      count: 3,
      avoidTitles: const ['Old Title'],
      extraHint: 'technology ethics',
    );

    expect(prompt, contains('language: english'));
    expect(prompt, contains('genre: argumentative'));
    expect(prompt, contains('difficulty: challenging'));
    expect(prompt, contains('count: 3'));
    expect(prompt, contains('Old Title'));
    expect(prompt, contains('technology ethics'));
  });
}
