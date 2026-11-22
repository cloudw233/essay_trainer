import '../../models/enums.dart';
import 'grading_prompts.dart';

/// Assembles the system and user prompts used by the grading client.
///
/// Keeping prompt text in one place makes it possible to tune the rubric
/// without touching the networking or persistence layers.
class PromptBuilder {
  const PromptBuilder._();

  static String systemPrompt({
    required EssayLanguage language,
    required EssayGenre genre,
    int? maxScore,
  }) {
    final base = switch (language) {
      EssayLanguage.english => englishGradingPrompt,
      EssayLanguage.chinese => chineseGradingPrompt,
    };
    final fullMark = maxScore ?? language.defaultMaxScore;

    return '$base\n\n'
        '本次写作体裁 / Genre: ${genre.label} (${genre.name})\n'
        '满分 / Full mark: $fullMark\n'
        '请严格按照 JSON 契约输出；所有维度分数之和必须等于 overallScore。';
  }

  static String userPrompt({
    required EssayLanguage language,
    required EssayGenre genre,
    required String title,
    required String content,
    required int maxScore,
    String rubric = '',
    String promptText = '',
  }) {
    final resolvedRubric = rubric.trim().isEmpty
        ? '未提供额外评分标准，请使用该语言与体裁的通用评分标准。'
        : rubric.trim();
    final promptContext = promptText.trim().isEmpty
        ? '题目：未提供独立题目，请根据标题和正文判断写作任务。'
        : '题目与写作要求：\n"""\n${promptText.trim()}\n"""';

    return '请批改下面这篇${language.shortLabel}。\n\n'
        '体裁：${genre.label}\n'
        '标题：${title.trim()}\n'
        '$promptContext\n'
        '满分：$maxScore\n'
        '评分标准：\n$resolvedRubric\n\n'
        '作文原文：\n"""\n$content\n"""\n\n'
        '请先审题，再逐句、逐段分析，最后按维度评分并给出全文改写版。';
  }
}
