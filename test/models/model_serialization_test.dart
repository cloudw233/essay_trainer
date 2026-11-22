import 'dart:convert';

import 'package:essay_trainer/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);

  group('EssayDraft', () {
    test('round-trips through its SQLite row', () {
      final draft = EssayDraft(
        id: 'draft-1',
        title: 'The Quiet Morning',
        language: EssayLanguage.english,
        genre: EssayGenre.narrative,
        content: 'The city was still asleep.',
        wordCount: 5,
        createdAt: createdAt,
        updatedAt: createdAt.add(const Duration(minutes: 2)),
      );

      final restored = EssayDraft.fromDbMap(draft.toDbMap());

      expect(restored.id, draft.id);
      expect(restored.title, draft.title);
      expect(restored.language, EssayLanguage.english);
      expect(restored.genre, EssayGenre.narrative);
      expect(restored.content, draft.content);
      expect(restored.wordCount, 5);
      expect(restored.createdAt.toUtc(), createdAt);
      expect(
        restored.updatedAt.toUtc(),
        createdAt.add(const Duration(minutes: 2)),
      );
    });

    test('keeps the prompt snapshot and preset id on a draft', () {
      final draft = EssayDraft(
        id: 'draft-prompt',
        title: 'A Turning Point',
        language: EssayLanguage.english,
        genre: EssayGenre.narrative,
        content: 'The morning was cold.',
        wordCount: 4,
        createdAt: createdAt,
        updatedAt: createdAt,
        promptText:
            'Write a narrative about a small decision. At least 120 words.',
        promptPresetId: 'preset-1',
      );

      final restored = EssayDraft.fromDbMap(draft.toDbMap());

      expect(restored.hasPrompt, isTrue);
      expect(restored.promptText, contains('At least 120 words'));
      expect(restored.promptPresetId, 'preset-1');
    });

    test('copyWith preserves identity when only content changes', () {
      final draft = EssayDraft(
        id: 'draft-1',
        title: 'Draft',
        language: EssayLanguage.chinese,
        genre: EssayGenre.other,
        content: '',
        wordCount: 0,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final updated = draft.copyWith(content: '新内容', updatedAt: createdAt);

      expect(updated.id, draft.id);
      expect(updated.createdAt, draft.createdAt);
      expect(updated.content, '新内容');
      expect(updated.language, EssayLanguage.chinese);
    });
  });

  group('GradingReport', () {
    test('round-trips nested dimensions and feedback through SQLite', () {
      final report = GradingReport(
        id: 'report-1',
        draftId: 'draft-1',
        overallScore: 21,
        maxScore: 25,
        dimensionScores: const [
          DimensionScore(
            name: '内容',
            score: 8,
            maxScore: 10,
            comment: '观点清晰，但论据还可以更具体。',
          ),
        ],
        sentenceFeedback: const [
          SentenceFeedback(
            sentenceIndex: 0,
            originalText: 'I very like it.',
            issueType: FeedbackIssueType.wordChoice,
            severity: FeedbackSeverity.critical,
            comment: 'very 不能直接修饰动词。',
            suggestion: 'I like it very much.',
          ),
        ],
        paragraphFeedback: const [
          ParagraphFeedback(
            paragraphIndex: 0,
            coherenceComment: '开头自然。',
            contentComment: '中心句明确。',
            suggestion: '补一个具体例子。',
          ),
        ],
        revisedEssay: 'I like it very much.',
        rawAiResponse: '{"overallScore":21}',
        createdAt: createdAt,
      );

      final restored = GradingReport.fromDbMap(report.toDbMap());

      expect(restored.id, report.id);
      expect(restored.draftId, report.draftId);
      expect(restored.overallScore, 21);
      expect(restored.maxScore, 25);
      expect(restored.createdAt.toUtc(), createdAt);
      expect(restored.dimensionScores.single.name, '内容');
      expect(
        restored.sentenceFeedback.single.severity,
        FeedbackSeverity.critical,
      );
      expect(
        restored.sentenceFeedback.single.issueType,
        FeedbackIssueType.wordChoice,
      );
      expect(restored.paragraphFeedback.single.suggestion, '补一个具体例子。');
      expect(restored.revisedEssay, 'I like it very much.');
      expect(restored.rawAiResponse, '{"overallScore":21}');
    });

    test('maps the AI tool payload into a report', () {
      final payload = <String, dynamic>{
        'overallScore': 20.5,
        'maxScore': 25,
        'dimensionScores': [
          {'name': '内容', 'score': 8.5, 'maxScore': 10, 'comment': '切题。'},
        ],
        'sentenceFeedback': [
          {
            'sentenceIndex': 1,
            'originalText': 'It is very important.',
            'issueType': 'wordChoice',
            'severity': 'minor',
            'comment': '表达偏弱。',
            'suggestion': 'It matters a great deal.',
          },
        ],
        'paragraphFeedback': [
          {
            'paragraphIndex': 0,
            'coherenceComment': '衔接顺畅。',
            'contentComment': '内容完整。',
            'suggestion': '可增加对比。',
          },
        ],
        'revisedEssay': 'It matters a great deal.',
      };

      final report = GradingReport.fromAiJson(
        payload,
        id: 'report-2',
        draftId: 'draft-2',
        rawAiResponse: jsonEncode(payload),
        createdAt: createdAt,
      );

      expect(report.overallScore, 20.5);
      expect(report.dimensionScores.single.score, 8.5);
      expect(
        report.sentenceFeedback.single.issueType,
        FeedbackIssueType.wordChoice,
      );
      expect(report.sentenceFeedback.single.severity, FeedbackSeverity.minor);
      expect(report.createdAt, createdAt);
    });
  });

  test('PromptPreset round-trips through its SQLite row', () {
    final preset = PromptPreset(
      id: 'preset-1',
      name: '上海高考英语',
      language: EssayLanguage.english,
      genre: EssayGenre.application,
      promptText: 'Write a letter to your foreign friend.',
      rubricText: '内容、语言、结构各占一部分。',
      maxScore: 25,
      createdAt: createdAt,
      source: PromptSource.ai,
      difficulty: PromptDifficulty.challenging,
      suggestedWordCount: 120,
      rationale: '考查在具体语境中提出论点的能力。',
    );

    final restored = PromptPreset.fromDbMap(preset.toDbMap());

    expect(restored.id, preset.id);
    expect(restored.name, preset.name);
    expect(restored.language, EssayLanguage.english);
    expect(restored.genre, EssayGenre.application);
    expect(restored.promptText, preset.promptText);
    expect(restored.rubricText, preset.rubricText);
    expect(restored.maxScore, 25);
    expect(restored.createdAt.toUtc(), createdAt);
    expect(restored.source, PromptSource.ai);
    expect(restored.difficulty, PromptDifficulty.challenging);
    expect(restored.suggestedWordCount, 120);
    expect(restored.rationale, '考查在具体语境中提出论点的能力。');
  });
}
