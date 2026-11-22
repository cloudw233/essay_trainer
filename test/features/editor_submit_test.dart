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
  final List<EssayDraft> saved = [];

  @override
  Future<void> save(EssayDraft draft) async => saved.add(draft);

  @override
  Future<EssayDraft?> findById(String id) async => null;

  @override
  Future<List<EssayDraft>> recent({int limit = 5}) async => const [];

  @override
  Future<List<EssayDraft>> all() async => const [];

  @override
  Future<void> delete(String id) async {}
}
