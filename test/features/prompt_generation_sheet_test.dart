import 'dart:convert';

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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows three candidates and saves one favorite', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final keyStore = _MemoryKeyStore('sk-ui-test');
    final keys = ApiKeyController(keyStore);
    await keys.load();
    final presets = _MemoryPresetRepository();
    final controller = PromptGenerationController(
      service: PromptGenerationService(httpClient: MockClient(_handler)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.light)),
        home: Scaffold(
          body: PromptGenerationSheet(
            controller: controller,
            apiKeys: keys,
            presets: presets,
            initialLanguage: EssayLanguage.english,
            initialGenre: EssayGenre.argumentative,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 出题'), findsOneWidget);
    final generate = find.text('生成 3 道候选');
    await tester.ensureVisible(generate);
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();

    expect(find.text('候选题目'), findsOneWidget);
    expect(find.text('选这道'), findsNWidgets(3));
    expect(find.text('Candidate A'), findsOneWidget);
    expect(find.text('收藏'), findsNWidgets(3));

    await tester.tap(find.text('收藏').first);
    await tester.pumpAndSettle();

    expect(presets.items, hasLength(1));
    expect(presets.items.single.source, PromptSource.ai);
    expect(find.text('已收藏'), findsOneWidget);
  });
}

Future<http.Response> _handler(http.Request request) async {
  final content = jsonEncode({
    'prompts': [
      {
        'title': 'Candidate A',
        'promptText':
            'Write a letter to a friend explaining a choice. At least 120 words.',
        'suggestedWordCount': 120,
        'difficulty': 'standard',
        'genre': 'application',
        'rationale': 'Tests a concrete decision and an authentic audience.',
      },
      {
        'title': 'Candidate B',
        'promptText':
            'Write an argumentative essay about a campus rule. At least 150 words.',
        'suggestedWordCount': 150,
        'difficulty': 'standard',
        'genre': 'argumentative',
        'rationale': 'Tests a clear position and reasoning.',
      },
      {
        'title': 'Candidate C',
        'promptText':
            'Write a narrative about a missed bus. At least 150 words.',
        'suggestedWordCount': 150,
        'difficulty': 'standard',
        'genre': 'narrative',
        'rationale': 'Tests a concrete moment and reflection.',
      },
    ],
  });
  return http.Response(
    jsonEncode({
      'id': 'chatcmpl-ui-test',
      'created': 0,
      'choices': [
        {
          'index': 0,
          'finish_reason': 'stop',
          'message': {'role': 'assistant', 'content': content},
        },
      ],
      'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
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

class _MemoryPresetRepository implements PresetRepository {
  final List<PromptPreset> items = [];

  @override
  Future<void> save(PromptPreset preset) async {
    items.add(preset);
  }

  @override
  Future<List<PromptPreset>> all() async => List.unmodifiable(items);

  @override
  Future<void> delete(String id) async {
    items.removeWhere((preset) => preset.id == id);
  }
}
