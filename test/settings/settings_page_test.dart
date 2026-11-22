import 'package:essay_trainer/core/database/settings_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/core/theme/theme_controller.dart';
import 'package:essay_trainer/features/settings/api_key_controller.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/features/settings/settings_page.dart';
import 'package:essay_trainer/features/settings/writing_defaults_controller.dart';
import 'package:essay_trainer/services/deepseek_service.dart';
import 'package:essay_trainer/services/secure_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeController', () {
    test('persists a selected mode and reloads it', () async {
      final settings = _MemorySettingsRepository();
      final first = ThemeController(settings: settings);
      await first.setMode(ThemeMode.dark);

      final second = ThemeController(settings: settings);
      await second.load();

      expect(settings.values[ThemeController.storageKey], 'dark');
      expect(second.mode, ThemeMode.dark);
    });

    testWidgets('settings segmented control switches the controller', (
      tester,
    ) async {
      final settings = _MemorySettingsRepository();
      final controller = ThemeController(settings: settings);
      final keyStore = _MemoryKeyStore();
      final keys = ApiKeyController(keyStore);
      await keys.load();
      final defaults = WritingDefaultsController(settings: settings);
      await defaults.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
          home: SettingsPage(
            themeController: controller,
            apiKeys: keys,
            deepSeekService: DeepSeekService(),
            writingDefaults: defaults,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();

      expect(controller.mode, ThemeMode.dark);
      expect(settings.values[ThemeController.storageKey], 'dark');
    });
  });

  testWidgets('save key is primary and test connection is secondary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final settings = _MemorySettingsRepository();
    final controller = ThemeController(settings: settings);
    final keys = ApiKeyController(_MemoryKeyStore());
    await keys.load();
    final defaults = WritingDefaultsController(settings: settings);
    await defaults.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: SettingsPage(
          themeController: controller,
          apiKeys: keys,
          deepSeekService: DeepSeekService(),
          writingDefaults: defaults,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('保存密钥'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.ancestor(
        of: find.text('保存密钥'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('测试连接'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      ),
      findsOneWidget,
    );
  });

  test('writing defaults persist and reload', () async {
    final settings = _MemorySettingsRepository();
    final first = WritingDefaultsController(settings: settings);
    await first.setLanguage(EssayLanguage.english);
    await first.setGenre(EssayGenre.argumentative);

    final second = WritingDefaultsController(settings: settings);
    await second.load();

    expect(second.language, EssayLanguage.english);
    expect(second.genre, EssayGenre.argumentative);
  });

  group('ApiKeyController', () {
    test(
      'loads, saves, and removes a key without exposing it in settings state',
      () async {
        final store = _MemoryKeyStore()..value = 'sk-existing';
        final controller = ApiKeyController(store);

        await controller.load();
        expect(controller.hasKey, isTrue);
        expect(controller.apiKey, 'sk-existing');

        await controller.save(' sk-new ');
        expect(controller.apiKey, 'sk-new');
        expect(store.value, 'sk-new');

        await controller.clear();
        expect(controller.hasKey, isFalse);
        expect(store.value, isNull);
      },
    );
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _MemoryKeyStore implements SecureKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String apiKey) async {
    value = apiKey.trim();
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}
