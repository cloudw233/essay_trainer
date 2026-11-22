import 'enums.dart';
import 'generated_prompt.dart';

/// A saved writing prompt together with its rubric.
///
/// `name` is the display title. It intentionally stays named `name` because
/// the original local schema already used that column; AI candidates map their
/// `title` into it when the user taps "收藏".
class PromptPreset {
  const PromptPreset({
    required this.id,
    required this.name,
    required this.language,
    required this.genre,
    required this.promptText,
    required this.rubricText,
    required this.maxScore,
    required this.createdAt,
    this.source = PromptSource.manual,
    this.difficulty = PromptDifficulty.standard,
    this.suggestedWordCount = 0,
    this.rationale = '',
  });

  final String id;
  final String name;
  final EssayLanguage language;
  final EssayGenre genre;
  final String promptText;
  final String rubricText;
  final int maxScore;
  final PromptSource source;
  final PromptDifficulty difficulty;
  final int suggestedWordCount;
  final String rationale;
  final DateTime createdAt;

  String get title => name;

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'name': name,
      'language': language.name,
      'genre': genre.name,
      'prompt_text': promptText,
      'rubric_text': rubricText,
      'max_score': maxScore,
      'source': source.name,
      'difficulty': difficulty.name,
      'suggested_word_count': suggestedWordCount,
      'rationale': rationale,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PromptPreset.fromDbMap(Map<String, Object?> map) {
    return PromptPreset(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      language: essayLanguageFromValue(map['language'] as String?),
      genre: essayGenreFromValue(map['genre'] as String?),
      promptText: (map['prompt_text'] as String?) ?? '',
      rubricText: (map['rubric_text'] as String?) ?? '',
      maxScore: _asInt(map['max_score']),
      source: promptSourceFromValue(map['source'] as String?),
      difficulty: promptDifficultyFromValue(map['difficulty'] as String?),
      suggestedWordCount: _asInt(map['suggested_word_count']),
      rationale: (map['rationale'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(_asInt(map['created_at'])),
    );
  }

  /// Builds a library row from an AI candidate. Kept here as well as on
  /// [GeneratedPrompt] so callers can choose which layer owns id creation.
  factory PromptPreset.fromGenerated(
    GeneratedPrompt prompt, {
    required String id,
    DateTime? createdAt,
  }) {
    return prompt.toPreset(id: id, createdAt: createdAt);
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
