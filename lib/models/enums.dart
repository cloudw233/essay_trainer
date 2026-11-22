/// The two writing languages supported by the app.
enum EssayLanguage { chinese, english }

extension EssayLanguageInfo on EssayLanguage {
  String get label => switch (this) {
    EssayLanguage.chinese => '语文',
    EssayLanguage.english => '英语',
  };

  String get shortLabel => switch (this) {
    EssayLanguage.chinese => '语文作文',
    EssayLanguage.english => '英语作文',
  };

  String get countUnit => switch (this) {
    EssayLanguage.chinese => '字',
    EssayLanguage.english => '词',
  };

  /// The minimum amount of content required before submitting for review.
  int get minimumWords => switch (this) {
    EssayLanguage.chinese => 300,
    EssayLanguage.english => 60,
  };

  /// Default full mark. The user can override this in a later phase.
  int get defaultMaxScore => switch (this) {
    EssayLanguage.chinese => 50,
    EssayLanguage.english => 25,
  };

  String get titleHint => switch (this) {
    EssayLanguage.chinese => '例如：那一刻，我长大了',
    EssayLanguage.english => 'e.g. A Turning Point',
  };

  String get bodyHint => switch (this) {
    EssayLanguage.chinese => '从一处细节写起。不必急着讲道理，先把当时看见、听见、想到的写下来……',
    EssayLanguage.english =>
      'Start with a concrete moment. What did you see, hear, or feel?',
  };
}

EssayLanguage essayLanguageFromValue(String? value) {
  return EssayLanguage.values.firstWhere(
    (language) => language.name == value,
    orElse: () => EssayLanguage.chinese,
  );
}

/// The genres offered in the writing brief.
enum EssayGenre { narrative, argumentative, expository, application, other }

extension EssayGenreInfo on EssayGenre {
  String get label => switch (this) {
    EssayGenre.narrative => '记叙文',
    EssayGenre.argumentative => '议论文',
    EssayGenre.expository => '说明文',
    EssayGenre.application => '应用文',
    EssayGenre.other => '其他',
  };

  String get hint => switch (this) {
    EssayGenre.narrative => '以事写人，以细节见真情',
    EssayGenre.argumentative => '观点明确，论据有力',
    EssayGenre.expository => '条理清楚，说明准确',
    EssayGenre.application => '格式规范，目的清晰',
    EssayGenre.other => '自由表达，不拘一格',
  };
}

EssayGenre essayGenreFromValue(String? value) {
  return EssayGenre.values.firstWhere(
    (genre) => genre.name == value,
    orElse: () => EssayGenre.other,
  );
}

/// Strict parser used by AI output validation. Unlike [essayGenreFromValue],
/// an unknown value is a validation failure rather than a silent fallback.
EssayGenre? essayGenreOrNull(String? value) {
  for (final genre in EssayGenre.values) {
    if (genre.name == value) return genre;
  }
  return null;
}

/// The amount of constraint and analytical tension in a generated prompt.
enum PromptDifficulty { basic, standard, challenging }

extension PromptDifficultyInfo on PromptDifficulty {
  String get label => switch (this) {
    PromptDifficulty.basic => '基础',
    PromptDifficulty.standard => '标准',
    PromptDifficulty.challenging => '挑战',
  };

  String get hint => switch (this) {
    PromptDifficulty.basic => '情境清晰，写作方向明确',
    PromptDifficulty.standard => '符合常规考试要求',
    PromptDifficulty.challenging => '需要辨析二元张力或隐含前提',
  };
}

PromptDifficulty promptDifficultyFromValue(String? value) {
  return PromptDifficulty.values.firstWhere(
    (difficulty) => difficulty.name == value,
    orElse: () => PromptDifficulty.standard,
  );
}

PromptDifficulty? promptDifficultyOrNull(String? value) {
  for (final difficulty in PromptDifficulty.values) {
    if (difficulty.name == value) return difficulty;
  }
  return null;
}

/// Where a saved prompt came from.
enum PromptSource { ai, manual }

extension PromptSourceInfo on PromptSource {
  String get label => switch (this) {
    PromptSource.ai => 'AI 收藏',
    PromptSource.manual => '手动创建',
  };
}

PromptSource promptSourceFromValue(String? value) {
  return PromptSource.values.firstWhere(
    (source) => source.name == value,
    orElse: () => PromptSource.manual,
  );
}

/// The kinds of sentence-level observations the model may report.
enum FeedbackIssueType { grammar, wordChoice, coherence, spelling, praise }

extension FeedbackIssueTypeInfo on FeedbackIssueType {
  String get label => switch (this) {
    FeedbackIssueType.grammar => '语法',
    FeedbackIssueType.wordChoice => '用词',
    FeedbackIssueType.coherence => '衔接',
    FeedbackIssueType.spelling => '拼写',
    FeedbackIssueType.praise => '亮点',
  };
}

FeedbackIssueType feedbackIssueTypeFromValue(String? value) {
  return FeedbackIssueType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => FeedbackIssueType.grammar,
  );
}

FeedbackIssueType? feedbackIssueTypeOrNull(String? value) {
  for (final type in FeedbackIssueType.values) {
    if (type.name == value) return type;
  }
  return null;
}

/// How strongly a piece of feedback should be surfaced.
enum FeedbackSeverity { critical, minor, suggestion, highlight }

extension FeedbackSeverityInfo on FeedbackSeverity {
  String get label => switch (this) {
    FeedbackSeverity.critical => '需修改',
    FeedbackSeverity.minor => '小问题',
    FeedbackSeverity.suggestion => '建议',
    FeedbackSeverity.highlight => '亮点',
  };
}

FeedbackSeverity feedbackSeverityFromValue(String? value) {
  return FeedbackSeverity.values.firstWhere(
    (severity) => severity.name == value,
    orElse: () => FeedbackSeverity.suggestion,
  );
}

FeedbackSeverity? feedbackSeverityOrNull(String? value) {
  for (final severity in FeedbackSeverity.values) {
    if (severity.name == value) return severity;
  }
  return null;
}
