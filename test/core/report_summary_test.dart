import 'package:essay_trainer/core/utils/report_summary.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

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
  );
  final report = GradingReport(
    id: 'report-1',
    draftId: draft.id,
    overallScore: 20,
    maxScore: 25,
    dimensionScores: const [
      DimensionScore(name: '内容', score: 8, maxScore: 10, comment: '切题。'),
    ],
    sentenceFeedback: const [
      SentenceFeedback(
        sentenceIndex: 0,
        originalText: 'The morning was cold.',
        issueType: FeedbackIssueType.praise,
        severity: FeedbackSeverity.highlight,
        comment: '开篇有画面感。',
        suggestion: 'Keep it.',
      ),
      SentenceFeedback(
        sentenceIndex: 1,
        originalText: 'I was very happy.',
        issueType: FeedbackIssueType.wordChoice,
        severity: FeedbackSeverity.minor,
        comment: '表达偏泛。',
        suggestion: 'Name the feeling.',
      ),
      SentenceFeedback(
        sentenceIndex: 2,
        originalText: 'Then I go home.',
        issueType: FeedbackIssueType.grammar,
        severity: FeedbackSeverity.critical,
        comment: '时态不一致。',
        suggestion: 'Then I went home.',
      ),
    ],
    paragraphFeedback: const [
      ParagraphFeedback(
        paragraphIndex: 0,
        coherenceComment: '衔接自然。',
        contentComment: '有情境。',
        suggestion: '补一个转折。',
      ),
    ],
    revisedEssay: 'The morning was cold. The street was empty.',
    rawAiResponse: '{}',
    createdAt: DateTime.utc(2026, 1, 2),
  );

  test('builds a portable full report summary', () {
    final summary = buildReportSummary(report: report, draft: draft);

    expect(summary, contains('文衡 · 批改报告'));
    expect(summary, contains('A Turning Point'));
    expect(summary, contains('总分：20 / 25'));
    expect(summary, contains('内容：8 / 10'));
    expect(summary, contains('逐句诊断（3 条）'));
    expect(summary, contains('The morning was cold.'));
    expect(summary, contains('开篇有画面感。'));
    expect(summary, contains('Then I went home.'));
    expect(summary, contains('逐段诊断'));
    expect(summary, contains('衔接自然。'));
    expect(summary, contains('全文升格'));
    expect(summary, contains('The morning was cold. The street was empty.'));
  });

  test('quotes the topic word count when the draft has one', () {
    final summary = buildReportSummary(
      report: report,
      draft: draft.copyWith(requiredWords: 800),
    );

    expect(summary, contains('800 词起'));
    expect(summary, isNot(contains('60 词起')));
  });

  test('falls back to a generic title when the draft is gone', () {
    final summary = buildReportSummary(report: report, draft: null);
    expect(summary, contains('批改报告'));
    expect(summary, isNot(contains('A Turning Point')));
  });
}
