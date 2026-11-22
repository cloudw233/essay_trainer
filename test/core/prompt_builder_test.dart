import 'package:essay_trainer/core/prompts/prompt_builder.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptBuilder', () {
    test('English prompt carries the four-step review and JSON contract', () {
      final prompt = PromptBuilder.systemPrompt(
        language: EssayLanguage.english,
        genre: EssayGenre.argumentative,
      );

      expect(prompt, contains('Step 1'));
      expect(prompt, contains('Step 2'));
      expect(prompt, contains('Step 3'));
      expect(prompt, contains('Step 4'));
      expect(prompt, contains('Content'));
      expect(prompt, contains('Language'));
      expect(prompt, contains('Structure'));
      expect(prompt, contains('议论文'));
      expect(prompt, contains('submit_grading_report'));
      expect(prompt, contains('dimensionScores'));
      expect(prompt, contains('sentenceFeedback'));
      expect(prompt, contains('paragraphFeedback'));
      expect(prompt, contains('revisedEssay'));
      expect(prompt.toLowerCase(), contains('json'));
    });

    test('Chinese prompt carries its own dimensions and upgrade essay', () {
      final prompt = PromptBuilder.systemPrompt(
        language: EssayLanguage.chinese,
        genre: EssayGenre.narrative,
      );

      expect(prompt, contains('立意与内容'));
      expect(prompt, contains('结构与层次'));
      expect(prompt, contains('语言与表达'));
      expect(prompt, contains('书写与规范'));
      expect(prompt, contains('记叙文'));
      expect(prompt, contains('全文升格'));
      expect(prompt, contains('sentenceFeedback'));
      expect(prompt, contains('revisedEssay'));
    });

    test('Chinese prompt gives anchored 20/15/10/5 maxima', () {
      final prompt = PromptBuilder.systemPrompt(
        language: EssayLanguage.chinese,
        genre: EssayGenre.narrative,
      );

      expect(prompt, contains('立意与内容（20 分）'));
      expect(prompt, contains('结构与层次（15 分）'));
      expect(prompt, contains('语言与表达（10 分）'));
      expect(prompt, contains('书写与规范（5 分）'));
      expect(prompt, contains('18–20'));
      expect(prompt, contains('13–15'));
      expect(prompt, contains('9–10'));
      expect(prompt, contains('不得改动维度名称或满分'));
    });

    test('includes the selected prompt text as grading context', () {
      final prompt = PromptBuilder.userPrompt(
        language: EssayLanguage.chinese,
        genre: EssayGenre.narrative,
        title: '那盏灯',
        content: '巷口的灯亮着。',
        maxScore: 50,
        promptText: '阅读下面的材料，根据要求写作。不少于 800 字，文体不限（诗歌除外）。',
      );

      expect(prompt, contains('题目与写作要求'));
      expect(prompt, contains('不少于 800 字'));
      expect(prompt, contains('巷口的灯亮着。'));
    });

    test('the user prompt includes the draft, limits, and rubric', () {
      final prompt = PromptBuilder.userPrompt(
        language: EssayLanguage.english,
        genre: EssayGenre.narrative,
        title: 'A Turning Point',
        content: 'It began on a rainy Tuesday.',
        maxScore: 25,
        rubric: '内容 10 分，语言 10 分，结构 5 分。',
      );

      expect(prompt, contains('A Turning Point'));
      expect(prompt, contains('It began on a rainy Tuesday.'));
      expect(prompt, contains('25'));
      expect(prompt, contains('内容 10 分'));
    });
  });
}
