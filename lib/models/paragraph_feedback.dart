/// Feedback attached to one paragraph of the original essay.
class ParagraphFeedback {
  const ParagraphFeedback({
    required this.paragraphIndex,
    required this.coherenceComment,
    required this.contentComment,
    required this.suggestion,
  });

  final int paragraphIndex;
  final String coherenceComment;
  final String contentComment;
  final String suggestion;

  Map<String, dynamic> toJson() {
    return {
      'paragraphIndex': paragraphIndex,
      'coherenceComment': coherenceComment,
      'contentComment': contentComment,
      'suggestion': suggestion,
    };
  }

  factory ParagraphFeedback.fromJson(Map<String, dynamic> json) {
    return ParagraphFeedback(
      paragraphIndex: _asInt(json['paragraphIndex']),
      coherenceComment: (json['coherenceComment'] as String?) ?? '',
      contentComment: (json['contentComment'] as String?) ?? '',
      suggestion: (json['suggestion'] as String?) ?? '',
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
