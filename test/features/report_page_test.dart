import 'package:essay_trainer/core/database/draft_repository.dart';
import 'package:essay_trainer/core/database/report_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/services/system_share.dart';
import 'package:essay_trainer/features/report/report_page.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows prompt, dimensions, three sentence feedbacks, and history data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final createdAt = DateTime.utc(2026, 1, 2);
      final draft = EssayDraft(
        id: 'draft-1',
        title: 'A Turning Point',
        language: EssayLanguage.english,
        genre: EssayGenre.narrative,
        content: 'The morning was cold and the street was empty.',
        wordCount: 9,
        createdAt: createdAt,
        updatedAt: createdAt,
        promptText:
            'Write a narrative about a small decision. At least 120 words.',
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
        createdAt: createdAt,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
          home: ReportPage(
            reportId: report.id,
            reports: _ReportRepo(report),
            drafts: _DraftRepo(draft),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Turning Point'), findsWidgets);
      expect(find.text('分维度评分'), findsOneWidget);
      expect(find.text('逐句诊断'), findsOneWidget);
      expect(find.text('本次题目'), findsOneWidget);
      expect(find.textContaining('At least 120 words'), findsOneWidget);
      expect(find.text('The morning was cold.'), findsOneWidget);
      expect(find.text('I was very happy.'), findsOneWidget);
      expect(find.text('Then I go home.'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.text('逐段诊断'), findsOneWidget);
      expect(find.text('建议：补一个转折。'), findsOneWidget);

      String? sharedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemShare.channel, (call) async {
            sharedText = (call.arguments as Map)['text'] as String?;
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemShare.channel, null);
      });
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();
      expect(sharedText, contains('A Turning Point'));
      expect(sharedText, contains('逐句诊断（3 条）'));
    },
  );
}

class _ReportRepo implements ReportRepository {
  _ReportRepo(this.report);
  final GradingReport report;

  @override
  Future<GradingReport?> findById(String id) async =>
      id == report.id ? report : null;

  @override
  Future<List<GradingReport>> all() async => [report];

  @override
  Future<void> save(GradingReport report) async {}

  @override
  Future<void> delete(String id) async {}
}

class _DraftRepo implements DraftRepository {
  _DraftRepo(this.draft);
  final EssayDraft draft;

  @override
  Future<EssayDraft?> findById(String id) async =>
      id == draft.id ? draft : null;

  @override
  Future<List<EssayDraft>> recent({int limit = 5}) async => [draft];

  @override
  Future<List<EssayDraft>> all() async => [draft];

  @override
  Future<void> save(EssayDraft draft) async {}

  @override
  Future<void> delete(String id) async {}
}
