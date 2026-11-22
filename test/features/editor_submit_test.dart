import 'package:essay_trainer/core/database/draft_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/features/editor/editor_page.dart';
import 'package:essay_trainer/features/settings/api_key_controller.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:essay_trainer/services/secure_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves and asks for a key before opening grading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final keys = ApiKeyController(_KeyStore());
    await keys.load();
    final drafts = _DraftRepo();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: EditorPage(
          drafts: drafts,
          apiKeys: keys,
          initialLanguage: EssayLanguage.english,
          initialGenre: EssayGenre.narrative,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'A Turning Point');
    await tester.enterText(fields.at(1), List.filled(130, 'word').join(' '));
    await tester.pump();

    await tester.tap(find.text('提交批改'));
    await tester.pumpAndSettle();

    expect(drafts.saved, hasLength(1));
    expect(drafts.saved.single.title, 'A Turning Point');
    expect(find.text('先配置 DeepSeek API Key'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
  });

  testWidgets('treats the topic word count as a target, not a gate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final keys = ApiKeyController(_KeyStore());
    await keys.load();
    final drafts = _DraftRepo(
      seed: EssayDraft(
        id: 'draft-target',
        title: '一封没有寄出的信',
        language: EssayLanguage.chinese,
        genre: EssayGenre.narrative,
        content: List.filled(200, '字').join(),
        wordCount: 200,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        promptText: '阅读下面的材料，根据要求写作。不少于 800 字。',
        requiredWords: 800,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: EditorPage(
          drafts: drafts,
          apiKeys: keys,
          draftId: 'draft-target',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('200 / 800 字'), findsOneWidget);
    expect(find.text('还差 600 字 · 仍可提交'), findsOneWidget);

    await tester.tap(find.text('提交批改'));
    await tester.pumpAndSettle();

    expect(drafts.saved, hasLength(1));
    expect(drafts.saved.single.requiredWords, 800);
    expect(find.text('先配置 DeepSeek API Key'), findsOneWidget);
  });
}

class _KeyStore implements SecureKeyStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String apiKey) async {}

  @override
  Future<void> delete() async {}
}

class _DraftRepo implements DraftRepository {
  _DraftRepo({this.seed});

  final EssayDraft? seed;
  final List<EssayDraft> saved = [];

  @override
  Future<void> save(EssayDraft draft) async => saved.add(draft);

  @override
  Future<EssayDraft?> findById(String id) async =>
      seed != null && seed!.id == id ? seed : null;

  @override
  Future<List<EssayDraft>> recent({int limit = 5}) async => const [];

  @override
  Future<List<EssayDraft>> all() async => const [];

  @override
  Future<void> delete(String id) async {}
}
