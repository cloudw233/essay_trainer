import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/models/generated_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 3, 4, 5, 6, 7);

  Map<String, dynamic> validJson() => {
    'title': '一封没有寄出的信',
    'promptText': '阅读下面的材料，根据要求写作。不少于 800 字，文体不限（诗歌除外）。',
    'suggestedWordCount': 800,
    'difficulty': 'challenging',
    'genre': 'narrative',
    'rationale': '考查具体物件与人物关系之间的情感转折。',
  };

  test('strictly parses a valid candidate and maps it to a preset', () {
    final prompt = GeneratedPrompt.fromJson(
      validJson(),
      id: 'prompt-1',
      language: EssayLanguage.chinese,
      createdAt: now,
    );

    expect(prompt.title, '一封没有寄出的信');
    expect(prompt.difficulty, PromptDifficulty.challenging);
    expect(prompt.genre, EssayGenre.narrative);
    expect(prompt.suggestedWordCount, 800);
    expect(prompt.source, PromptSource.ai);

    final preset = prompt.toPreset(id: 'preset-1');
    expect(preset.source, PromptSource.ai);
    expect(preset.title, prompt.title);
    expect(preset.suggestedWordCount, 800);
    expect(preset.difficulty, PromptDifficulty.challenging);

    final selection = prompt.toSelection(promptPresetId: 'preset-1');
    expect(selection.promptText, prompt.promptText);
    expect(selection.promptPresetId, 'preset-1');
  });

  test('carries the suggested word count into the draft it starts', () {
    final prompt = GeneratedPrompt.fromJson(
      validJson(),
      id: 'prompt-1',
      language: EssayLanguage.chinese,
      createdAt: now,
    );

    final draft = prompt.toSelection().toDraft(draftId: 'draft-1', now: now);

    expect(draft.requiredWords, 800);
    expect(draft.targetWords, 800);
    expect(draft.title, prompt.title);
    expect(draft.promptText, prompt.promptText);
  });

  test('rejects an empty promptText', () {
    final json = validJson()..['promptText'] = '  ';
    expect(
      () => GeneratedPrompt.fromJson(
        json,
        id: 'prompt-1',
        language: EssayLanguage.chinese,
        createdAt: now,
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown genre and difficulty values', () {
    expect(
      () => GeneratedPrompt.fromJson(
        validJson()..['genre'] = 'poetry',
        id: 'prompt-1',
        language: EssayLanguage.chinese,
        createdAt: now,
      ),
      throwsFormatException,
    );
    expect(
      () => GeneratedPrompt.fromJson(
        validJson()..['difficulty'] = 'impossible',
        id: 'prompt-1',
        language: EssayLanguage.chinese,
        createdAt: now,
      ),
      throwsFormatException,
    );
  });

  test('rejects a non-positive word count', () {
    expect(
      () => GeneratedPrompt.fromJson(
        validJson()..['suggestedWordCount'] = 0,
        id: 'prompt-1',
        language: EssayLanguage.chinese,
        createdAt: now,
      ),
      throwsFormatException,
    );
  });
}
