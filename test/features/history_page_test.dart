import 'package:essay_trainer/core/database/draft_repository.dart';
import 'package:essay_trainer/core/database/report_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/features/history/history_page.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists reports and deletes one by swiping', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final reports = _ReportRepo([
      _report('r1', 'd1', 'A Small Decision', 20, DateTime.utc(2026, 1, 2)),
      _report('r2', 'd2', 'The Quiet Library', 21, DateTime.utc(2026, 1, 1)),
    ]);
    final drafts = _DraftRepo({
      'd1': _draft('d1', 'A Small Decision'),
      'd2': _draft('d2', 'The Quiet Library'),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: HistoryPage(reports: reports, drafts: drafts),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A Small Decision'), findsOneWidget);
    expect(find.text('The Quiet Library'), findsOneWidget);
    expect(find.text('共 2 份'), findsOneWidget);

    await tester.drag(find.text('A Small Decision'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('删除这份报告？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(reports.deleted, ['r1']);
    expect(find.text('A Small Decision'), findsNothing);
    expect(find.text('The Quiet Library'), findsOneWidget);
  });

  testWidgets('empty history offers a start action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: HistoryPage(reports: _ReportRepo([]), drafts: _DraftRepo({})),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('去首页开始写作'), findsOneWidget);
  });
}

GradingReport _report(
  String id,
  String draftId,
  String title,
  double score,
  DateTime createdAt,
) {
  return GradingReport(
    id: id,
    draftId: draftId,
    overallScore: score,
    maxScore: 25,
    dimensionScores: const [
      DimensionScore(name: '内容', score: 8, maxScore: 10, comment: '切题。'),
    ],
    sentenceFeedback: const [
      SentenceFeedback(
        sentenceIndex: 0,
        originalText: 'A sentence.',
        issueType: FeedbackIssueType.praise,
        severity: FeedbackSeverity.highlight,
        comment: '好。',
        suggestion: 'Keep it.',
      ),
    ],
    paragraphFeedback: const [
      ParagraphFeedback(
        paragraphIndex: 0,
        coherenceComment: '自然。',
        contentComment: '有细节。',
        suggestion: '继续。',
      ),
    ],
    revisedEssay: 'A revised essay.',
    rawAiResponse: '{}',
    createdAt: createdAt,
  );
}

EssayDraft _draft(String id, String title) {
  return EssayDraft(
    id: id,
    title: title,
    language: EssayLanguage.english,
    genre: EssayGenre.narrative,
    content: 'Text.',
    wordCount: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class _ReportRepo implements ReportRepository {
  _ReportRepo(this.items);
  final List<GradingReport> items;
  final List<String> deleted = [];

  @override
  Future<List<GradingReport>> all() async => List.unmodifiable(items);

  @override
  Future<GradingReport?> findById(String id) async {
    for (final report in items) {
      if (report.id == id) return report;
    }
    return null;
  }

  @override
  Future<void> save(GradingReport report) async {}

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    items.removeWhere((report) => report.id == id);
  }
}

class _DraftRepo implements DraftRepository {
  _DraftRepo(this.items);
  final Map<String, EssayDraft> items;

  @override
  Future<EssayDraft?> findById(String id) async => items[id];

  @override
  Future<List<EssayDraft>> recent({int limit = 5}) async =>
      items.values.take(limit).toList(growable: false);

  @override
  Future<List<EssayDraft>> all() async => items.values.toList(growable: false);

  @override
  Future<void> save(EssayDraft draft) async => items[draft.id] = draft;

  @override
  Future<void> delete(String id) async => items.remove(id);
}
