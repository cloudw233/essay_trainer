import 'enums.dart';

/// Feedback attached to one sentence of the original essay.
class SentenceFeedback {
  const SentenceFeedback({
    required this.sentenceIndex,
    required this.originalText,
    required this.issueType,
    required this.severity,
    required this.comment,
    required this.suggestion,
  });

  final int sentenceIndex;
  final String originalText;
  final FeedbackIssueType issueType;
  final FeedbackSeverity severity;
  final String comment;
  final String suggestion;

  Map<String, dynamic> toJson() {
    return {
      'sentenceIndex': sentenceIndex,
      'originalText': originalText,
      'issueType': issueType.name,
      'severity': severity.name,
      'comment': comment,
      'suggestion': suggestion,
    };
  }

  factory SentenceFeedback.fromJson(Map<String, dynamic> json) {
    return SentenceFeedback(
      sentenceIndex: _asInt(json['sentenceIndex']),
      originalText: (json['originalText'] as String?) ?? '',
      issueType: feedbackIssueTypeFromValue(json['issueType'] as String?),
      severity: feedbackSeverityFromValue(json['severity'] as String?),
      comment: (json['comment'] as String?) ?? '',
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
