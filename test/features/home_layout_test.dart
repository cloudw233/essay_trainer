import 'package:essay_trainer/core/database/draft_repository.dart';
import 'package:essay_trainer/core/database/preset_repository.dart';
import 'package:essay_trainer/core/database/settings_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/features/home/home_page.dart';
import 'package:essay_trainer/features/prompt_generation/prompt_generation_controller.dart';
import 'package:essay_trainer/features/settings/api_key_controller.dart';
import 'package:essay_trainer/features/settings/writing_defaults_controller.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:essay_trainer/services/prompt_generation_service.dart';
import 'package:essay_trainer/services/secure_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('puts recent drafts before writing settings and keeps one CTA', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final settings = _MemorySettingsRepository();
    final defaults = WritingDefaultsController(settings: settings);
    await defaults.load();
    final keys = ApiKeyController(_MemoryKeyStore());
    await keys.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: HomePage(
          drafts: _DraftRepo([
            _draft('draft-1', 'A Small Decision', DateTime.utc(2026, 1, 2)),
            _draft('draft-2', 'The Quiet Library', DateTime.utc(2026, 1, 1)),
          ]),
          presets: _EmptyPresetRepository(),
          apiKeys: keys,
          writingDefaults: defaults,
          promptGeneration: PromptGenerationController(
            service: PromptGenerationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recentHeader = find.text('最近草稿');
    final settingsHeader = find.text('写作设置');
    expect(recentHeader, findsOneWidget);
    expect(settingsHeader, findsOneWidget);
    expect(
      tester.getTopLeft(recentHeader).dy,
      lessThan(tester.getTopLeft(settingsHeader).dy),
    );

    expect(
      find.ancestor(
        of: find.text('开始写作'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('AI 出题'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('AI 出题'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps the hero watermark at its original offset and clips at the card edge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _MemorySettingsRepository();
      final defaults = WritingDefaultsController(settings: settings);
      await defaults.load();
      final keys = ApiKeyController(_MemoryKeyStore());
      await keys.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
          home: HomePage(
            drafts: _DraftRepo([
              _draft('draft-1', 'A Small Decision', DateTime.utc(2026, 1, 2)),
            ]),
            presets: _EmptyPresetRepository(),
            apiKeys: keys,
            writingDefaults: defaults,
            promptGeneration: PromptGenerationController(
              service: PromptGenerationService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final watermark = find.text('文');
      expect(watermark, findsOneWidget);
      final stack = find
          .ancestor(of: watermark, matching: find.byType(Stack))
          .first;
      final cardFinder = find.ancestor(
        of: watermark,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.clipBehavior == Clip.antiAlias,
        ),
      );
      expect(cardFinder, findsOneWidget);

      final card = tester.widget<Container>(cardFinder.first);
      final decoration = card.decoration! as BoxDecoration;
      final radius = decoration.borderRadius! as BorderRadius;
      expect(radius.topRight, const Radius.circular(24));

      final watermarkRect = tester.getRect(watermark);
      final stackRect = tester.getRect(stack);
      expect(watermarkRect.top, closeTo(stackRect.top - 8, 0.01));
      expect(watermarkRect.right, closeTo(stackRect.right - 8, 0.01));
    },
  );
}

EssayDraft _draft(String id, String title, DateTime updatedAt) {
  return EssayDraft(
    id: id,
    title: title,
    language: EssayLanguage.english,
    genre: EssayGenre.narrative,
    content: 'Text.',
    wordCount: 1,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

class _DraftRepo implements DraftRepository {
  _DraftRepo(this.items);

  final List<EssayDraft> items;

  @override
  Future<List<EssayDraft>> recent({int limit = 5}) async =>
      items.take(limit).toList();

  @override
  Future<EssayDraft?> findById(String id) async => null;

  @override
  Future<List<EssayDraft>> all() async => List.unmodifiable(items);

  @override
  Future<void> save(EssayDraft draft) async {}

  @override
  Future<void> delete(String id) async {}
}

class _EmptyPresetRepository implements PresetRepository {
  @override
  Future<List<PromptPreset>> all() async => const [];

  @override
  Future<void> save(PromptPreset preset) async {}

  @override
  Future<void> delete(String id) async {}
}

class _MemorySettingsRepository implements SettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _MemoryKeyStore implements SecureKeyStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String apiKey) async {}

  @override
  Future<void> delete() async {}
}
