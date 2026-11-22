import 'enums.dart';

/// A piece of writing the user is working on.
///
/// The class is intentionally immutable: screens replace a draft rather than
/// mutating it, which keeps the editor and the database consistent.
class EssayDraft {
  const EssayDraft({
    required this.id,
    required this.title,
    required this.language,
    required this.genre,
    required this.content,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.promptText = '',
    this.promptPresetId,
    this.requiredWords = 0,
  });

  final String id;
  final String title;
  final EssayLanguage language;
  final EssayGenre genre;
  final String content;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Snapshot of the selected/imported prompt. Storing the full text here keeps
  /// the prompt bound to the essay even if the preset is later deleted.
  final String promptText;
  final String? promptPresetId;

  /// The word count the topic asks for, or 0 when the topic states none.
  ///
  /// It is a target rather than a submission gate: the editor shows progress
  /// against it and still lets the writer submit short, which the grading
  /// prompt can then judge.
  final int requiredWords;

  /// The word count to measure the essay against. Drafts without a topic
  /// target fall back to the language default.
  int get targetWords =>
      requiredWords > 0 ? requiredWords : language.minimumWords;

  bool get hasPrompt => promptText.trim().isNotEmpty;

  EssayDraft copyWith({
    String? id,
    String? title,
    EssayLanguage? language,
    EssayGenre? genre,
    String? content,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? promptText,
    String? promptPresetId,
    int? requiredWords,
  }) {
    return EssayDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      language: language ?? this.language,
      genre: genre ?? this.genre,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      promptText: promptText ?? this.promptText,
      promptPresetId: promptPresetId ?? this.promptPresetId,
      requiredWords: requiredWords ?? this.requiredWords,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'title': title,
      'language': language.name,
      'genre': genre.name,
      'content': content,
      'word_count': wordCount,
      'prompt_text': promptText,
      'prompt_preset_id': promptPresetId,
      'required_words': requiredWords,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory EssayDraft.fromDbMap(Map<String, Object?> map) {
    return EssayDraft(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      language: essayLanguageFromValue(map['language'] as String?),
      genre: essayGenreFromValue(map['genre'] as String?),
      content: (map['content'] as String?) ?? '',
      wordCount: _asInt(map['word_count']),
      promptText: (map['prompt_text'] as String?) ?? '',
      promptPresetId: map['prompt_preset_id'] as String?,
      requiredWords: _asInt(map['required_words']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(_asInt(map['created_at'])),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(_asInt(map['updated_at'])),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
