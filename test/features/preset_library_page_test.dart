import 'package:essay_trainer/core/database/preset_repository.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:essay_trainer/features/presets/preset_library_page.dart';
import 'package:essay_trainer/models/prompt_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty presets offers a create action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: PresetLibraryPage(presets: _EmptyPresetRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新建预设'), findsOneWidget);
  });
}

class _EmptyPresetRepository implements PresetRepository {
  @override
  Future<List<PromptPreset>> all() async => const [];

  @override
  Future<void> save(PromptPreset preset) async {}

  @override
  Future<void> delete(String id) async {}
}
