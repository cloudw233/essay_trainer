import 'dart:convert';

import 'package:essay_trainer/core/database/draft_repository.dart';
import 'package:essay_trainer/core/database/report_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/features/grading/grading_page.dart';
import 'package:essay_trainer/features/report/report_page.dart';
import 'package:essay_trainer/features/settings/api_key_controller.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:essay_trainer/services/grading_service.dart';
import 'package:essay_trainer/services/secure_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('submits, saves, and opens a prompt-linked report', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final draft = EssayDraft(
      id: 'draft-1',
      title: 'A Turning Point',
      language: EssayLanguage.english,
      genre: EssayGenre.narrative,
      content: 'The morning was cold and the street was empty.',
      wordCount: 9,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      promptText:
          'Write a narrative about a small decision. At least 120 words.',
    );
    final drafts = _DraftRepo(draft);
    final reports = _ReportRepo();
    final keys = ApiKeyController(_KeyStore('sk-test'));
    await keys.load();

    final service = GradingService(
      httpClient: MockClient((request) async => _reportResponse()),
    );

    final router = GoRouter(
      initialLocation: '/grading?draftId=${draft.id}',
      routes: [
        GoRoute(
          path: '/grading',
          builder: (context, state) => GradingPage(
            draftId: state.uri.queryParameters['draftId'] ?? '',
            drafts: drafts,
            reports: reports,
            apiKeys: keys,
            gradingService: service,
          ),
        ),
        GoRoute(
          path: '/report',
          builder: (context, state) => ReportPage(
            reportId: state.uri.queryParameters['reportId'] ?? '',
            reports: reports,
            drafts: drafts,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        routerConfig: router,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('A Turning Point'), findsWidgets);
    expect(find.text('批改报告'), findsOneWidget);
    expect(find.text('本次题目'), findsOneWidget);
    expect(find.textContaining('At least 120 words'), findsOneWidget);
    expect(find.text('The morning was cold.'), findsOneWidget);
    expect(find.text('I was very happy.'), findsOneWidget);
    expect(find.text('Then I go home.'), findsOneWidget);
    expect(reports.saved, hasLength(1));
    expect(reports.saved.single.draftId, draft.id);
  });

  testWidgets('no key puts the recovery action in the bottom bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    final keys = ApiKeyController(_KeyStore(null));
    await keys.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: GradingPage(
          draftId: draft.id,
          drafts: _DraftRepo(draft),
          reports: _ReportRepo(),
          apiKeys: keys,
          gradingService: GradingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bottom = find.byKey(const ValueKey('grading-bottom-actions'));
    expect(bottom, findsOneWidget);
    expect(
      find.descendant(of: bottom, matching: find.text('去设置 API Key')),
      findsOneWidget,
    );
  });
}

http.Response _reportResponse() {
  final payload = {
    'overallScore': 20,
    'maxScore': 25,
    'dimensionScores': [
      {'name': '内容', 'score': 8, 'maxScore': 10, 'comment': '切题。'},
    ],
    'sentenceFeedback': [
      {
        'sentenceIndex': 0,
        'originalText': 'The morning was cold.',
        'issueType': 'praise',
        'severity': 'highlight',
        'comment': '开篇有画面感。',
        'suggestion': 'Keep it.',
      },
      {
        'sentenceIndex': 1,
        'originalText': 'I was very happy.',
        'issueType': 'wordChoice',
        'severity': 'minor',
        'comment': '表达偏泛。',
        'suggestion': 'Name the feeling.',
      },
      {
        'sentenceIndex': 2,
        'originalText': 'Then I go home.',
        'issueType': 'grammar',
        'severity': 'critical',
        'comment': '时态不一致。',
        'suggestion': 'Then I went home.',
      },
    ],
    'paragraphFeedback': [
      {
        'paragraphIndex': 0,
        'coherenceComment': '衔接自然。',
        'contentComment': '有情境。',
        'suggestion': '补一个转折。',
      },
    ],
    'revisedEssay': 'The morning was cold. The street was empty.',
  };
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': 'call-1',
                'type': 'function',
                'function': {
                  'name': 'submit_grading_report',
                  'arguments': jsonEncode(payload),
                },
              },
            ],
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _KeyStore implements SecureKeyStore {
  _KeyStore(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String apiKey) async => value = apiKey;

  @override
  Future<void> delete() async => value = null;
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

class _ReportRepo implements ReportRepository {
  final List<GradingReport> saved = [];

  @override
  Future<GradingReport?> findById(String id) async {
    for (final report in saved) {
      if (report.id == id) return report;
    }
    return null;
  }

  @override
  Future<List<GradingReport>> all() async => List.unmodifiable(saved);

  @override
  Future<void> save(GradingReport report) async => saved.add(report);

  @override
  Future<void> delete(String id) async =>
      saved.removeWhere((report) => report.id == id);
}
