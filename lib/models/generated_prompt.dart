import 'enums.dart';
import 'essay_draft.dart';
import 'prompt_preset.dart';

/// A candidate returned by the AI prompt generator.
///
/// Candidates are not persisted directly. The user must explicitly select one
/// or save it as a [PromptPreset]; this class only validates and carries the
/// model output until that decision is made.
class GeneratedPrompt {
  const GeneratedPrompt({
    required this.id,
    required this.language,
    required this.genre,
    required this.title,
    required this.promptText,
    required this.suggestedWordCount,
    required this.difficulty,
    required this.rationale,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final EssayLanguage language;
  final EssayGenre genre;
  final String title;
  final String promptText;
  final int suggestedWordCount;
  final PromptDifficulty difficulty;
  final String rationale;
  final PromptSource source;
  final DateTime createdAt;

  /// Strictly parses one item from the model's `prompts` array.
  ///
  /// The user-facing contract deliberately fails loudly for bad enums or word
  /// counts. The service catches this and retries once instead of accepting a
  /// half-valid batch.
  factory GeneratedPrompt.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required EssayLanguage language,
    required DateTime createdAt,
  }) {
    final promptText = _requiredString(json['promptText'], 'promptText');
    final genre = essayGenreOrNull(_optionalString(json['genre'], 'genre'));
    if (genre == null) {
      throw FormatException(
        'genre 必须是 ${EssayGenre.values.map((value) => value.name).join('/')}',
      );
    }

    final difficulty = promptDifficultyOrNull(
      _optionalString(json['difficulty'], 'difficulty'),
    );
    if (difficulty == null) {
      throw FormatException(
        'difficulty 必须是 '
        '${PromptDifficulty.values.map((value) => value.name).join('/')}',
      );
    }

    final suggestedWordCount = _asInt(json['suggestedWordCount']);
    if (suggestedWordCount <= 0) {
      throw const FormatException('suggestedWordCount 必须是正整数');
    }

    return GeneratedPrompt(
      id: id,
      language: language,
      genre: genre,
      title: _optionalString(json['title'], 'title')?.trim() ?? '',
      promptText: promptText.trim(),
      suggestedWordCount: suggestedWordCount,
      difficulty: difficulty,
      rationale: _optionalString(json['rationale'], 'rationale')?.trim() ?? '',
      source: PromptSource.ai,
      createdAt: createdAt,
    );
  }

  PromptSelection toSelection({String? promptPresetId}) {
    return PromptSelection(
      title: title,
      promptText: promptText,
      language: language,
      genre: genre,
      suggestedWordCount: suggestedWordCount,
      promptPresetId: promptPresetId,
    );
  }

  /// Converts a candidate into the persistent library row. `name` serves as
  /// the title column because [PromptPreset] predates AI generation.
  PromptPreset toPreset({String? id, DateTime? createdAt}) {
    final trimmedTitle = title.trim();
    return PromptPreset(
      id: id ?? 'preset_${this.id}',
      name: trimmedTitle.isEmpty
          ? '材料作文 · ${language.label} · ${genre.label}'
          : trimmedTitle,
      language: language,
      genre: genre,
      promptText: promptText,
      rubricText: '',
      maxScore: language.defaultMaxScore,
      source: PromptSource.ai,
      difficulty: difficulty,
      suggestedWordCount: suggestedWordCount,
      rationale: rationale,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Creates the draft row that binds this prompt to the essay.
  EssayDraft toDraft({
    required String draftId,
    required DateTime now,
    String? promptPresetId,
  }) {
    return toSelection(
      promptPresetId: promptPresetId,
    ).toDraft(draftId: draftId, now: now);
  }
}

/// The explicit choice the generation sheet returns to the home page.
///
/// Returning a selection instead of mutating the current draft is what keeps
/// AI generation candidate-based rather than an automatic black box.
class PromptSelection {
  const PromptSelection({
    required this.title,
    required this.promptText,
    required this.language,
    required this.genre,
    required this.suggestedWordCount,
    this.promptPresetId,
  });

  final String title;
  final String promptText;
  final EssayLanguage language;
  final EssayGenre genre;
  final int suggestedWordCount;
  final String? promptPresetId;

  /// Creates the draft that starts from this choice, keeping the topic's word
  /// count so the editor can measure the essay against it.
  EssayDraft toDraft({required String draftId, required DateTime now}) {
    final trimmedTitle = title.trim();
    return EssayDraft(
      id: draftId,
      title: trimmedTitle.isEmpty ? '未命名草稿' : trimmedTitle,
      language: language,
      genre: genre,
      content: '',
      wordCount: 0,
      createdAt: now,
      updatedAt: now,
      promptText: promptText,
      promptPresetId: promptPresetId,
      requiredWords: suggestedWordCount,
    );
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field 必须是非空字符串');
  }
  return value;
}

String? _optionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$field 必须是字符串');
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
