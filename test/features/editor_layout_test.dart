import 'package:essay_trainer/core/database/draft_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/core/theme/app_widgets.dart';
import 'package:essay_trainer/features/editor/editor_page.dart';
import 'package:essay_trainer/features/settings/api_key_controller.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:essay_trainer/services/secure_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the submit action above the keyboard', (tester) async {
    await _pumpEditor(
      tester,
      textScaler: TextScaler.noScaling,
      viewInsets: const EdgeInsets.only(bottom: 300),
    );

    final submit = find.widgetWithText(FilledButton, '提交批改');
    expect(submit, findsOneWidget);
    expect(tester.getBottomLeft(submit).dy, lessThanOrEqualTo(500));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('does not overflow at 1.3x with the keyboard open', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      textScaler: const TextScaler.linear(1.3),
      viewInsets: const EdgeInsets.only(bottom: 300),
    );

    expect(tester.takeException(), isNull);
    final submit = find.widgetWithText(FilledButton, '提交批改');
    expect(submit, findsOneWidget);
    expect(tester.getBottomLeft(submit).dy, lessThanOrEqualTo(500));
  });

  testWidgets('caps the prompt preview so the body keeps room', (tester) async {
    await _pumpEditor(tester, size: const Size(420, 1000));

    final header = find.text('作文题');
    expect(header, findsOneWidget);
    final surface = find
        .ancestor(of: header, matching: find.byType(AppSurface))
        .first;
    expect(tester.getSize(surface).height, lessThan(150));
  });

  testWidgets('shows AI grading as plain status text, not a pill', (
    tester,
  ) async {
    await _pumpEditor(tester, size: const Size(420, 1000));

    expect(find.widgetWithText(StatusPill, 'AI 批改'), findsNothing);
    expect(find.text('AI 批改'), findsOneWidget);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final keys = ApiKeyController(_NoKeyStore());
  await keys.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: textScaler,
          viewInsets: viewInsets,
        ),
        child: EditorPage(
          drafts: _DraftRepo(_draft()),
          apiKeys: keys,
          draftId: 'draft-1',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

EssayDraft _draft() {
  return EssayDraft(
    id: 'draft-1',
    title: 'A Small Decision',
    language: EssayLanguage.english,
    genre: EssayGenre.narrative,
    content: 'The morning was cold and the street was empty.',
    wordCount: 10,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    promptText:
        'Write a narrative about a small decision that changed your day. '
        'At least 120 words. Use specific details and a clear turning point.',
  );
}

class _NoKeyStore implements SecureKeyStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String apiKey) async {}

  @override
  Future<void> delete() async {}
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
