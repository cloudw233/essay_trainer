import 'package:essay_trainer/core/database/preset_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/features/prompt_generation/prompt_generation_controller.dart';
import 'package:essay_trainer/features/prompt_generation/prompt_generation_sheet.dart';
import 'package:essay_trainer/features/settings/api_key_controller.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/models/prompt_preset.dart';
import 'package:essay_trainer/services/prompt_generation_service.dart';
import 'package:essay_trainer/services/secure_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the hint field and generate action above the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final keys = ApiKeyController(_MemoryKeyStore('sk-test'));
    await keys.load();
    final controller = PromptGenerationController(
      service: PromptGenerationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(420, 900),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: SizedBox(
              height: 900,
              child: PromptGenerationSheet(
                controller: controller,
                apiKeys: keys,
                presets: _EmptyPresetRepository(),
                initialLanguage: EssayLanguage.chinese,
                initialGenre: EssayGenre.narrative,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final generate = find.text('生成 3 道候选');
    expect(generate.hitTestable(), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(generate).dy, lessThanOrEqualTo(600));
  });
}

class _MemoryKeyStore implements SecureKeyStore {
  _MemoryKeyStore(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String apiKey) async => value = apiKey;

  @override
  Future<void> delete() async => value = null;
}

class _EmptyPresetRepository implements PresetRepository {
  @override
  Future<void> save(PromptPreset preset) async {}

  @override
  Future<List<PromptPreset>> all() async => const [];

  @override
  Future<void> delete(String id) async {}
}
