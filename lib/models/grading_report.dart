import 'dart:convert';

import 'dimension_score.dart';
import 'paragraph_feedback.dart';
import 'sentence_feedback.dart';

/// The structured result of one AI review.
class GradingReport {
  const GradingReport({
    required this.id,
    required this.draftId,
    required this.overallScore,
    required this.maxScore,
    required this.dimensionScores,
    required this.sentenceFeedback,
    required this.paragraphFeedback,
    required this.revisedEssay,
    required this.rawAiResponse,
    required this.createdAt,
  });

  final String id;
  final String draftId;
  final double overallScore;
  final double maxScore;
  final List<DimensionScore> dimensionScores;
  final List<SentenceFeedback> sentenceFeedback;
  final List<ParagraphFeedback> paragraphFeedback;
  final String revisedEssay;
  final String rawAiResponse;
  final DateTime createdAt;

  double get scoreRatio {
    if (maxScore <= 0) return 0;
    return (overallScore / maxScore).clamp(0.0, 1.0);
  }

  /// Builds a report from the JSON payload returned by the grading tool.
  ///
  /// `id`, `draftId`, and `createdAt` are local metadata and are therefore
  /// supplied by the caller rather than trusted to the model.
  factory GradingReport.fromAiJson(
    Map<String, dynamic> json, {
    required String id,
    required String draftId,
    required String rawAiResponse,
    required DateTime createdAt,
  }) {
    return GradingReport(
      id: id,
      draftId: draftId,
      overallScore: _asDouble(json['overallScore']),
      maxScore: _asDouble(json['maxScore'], fallback: 100),
      dimensionScores: _asList(
        json['dimensionScores'],
      ).map((item) => DimensionScore.fromJson(item)).toList(growable: false),
      sentenceFeedback: _asList(
        json['sentenceFeedback'],
      ).map((item) => SentenceFeedback.fromJson(item)).toList(growable: false),
      paragraphFeedback: _asList(
        json['paragraphFeedback'],
      ).map((item) => ParagraphFeedback.fromJson(item)).toList(growable: false),
      revisedEssay: (json['revisedEssay'] as String?) ?? '',
      rawAiResponse: rawAiResponse,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'draft_id': draftId,
      'overall_score': overallScore,
      'max_score': maxScore,
      'dimension_scores': jsonEncode(
        dimensionScores.map((score) => score.toJson()).toList(),
      ),
      'sentence_feedback': jsonEncode(
        sentenceFeedback.map((feedback) => feedback.toJson()).toList(),
      ),
      'paragraph_feedback': jsonEncode(
        paragraphFeedback.map((feedback) => feedback.toJson()).toList(),
      ),
      'revised_essay': revisedEssay,
      'raw_ai_response': rawAiResponse,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory GradingReport.fromDbMap(Map<String, Object?> map) {
    return GradingReport(
      id: (map['id'] as String?) ?? '',
      draftId: (map['draft_id'] as String?) ?? '',
      overallScore: _asDouble(map['overall_score']),
      maxScore: _asDouble(map['max_score']),
      dimensionScores: _asList(
        _decodeJsonList(map['dimension_scores']),
      ).map((item) => DimensionScore.fromJson(item)).toList(growable: false),
      sentenceFeedback: _asList(
        _decodeJsonList(map['sentence_feedback']),
      ).map((item) => SentenceFeedback.fromJson(item)).toList(growable: false),
      paragraphFeedback: _asList(
        _decodeJsonList(map['paragraph_feedback']),
      ).map((item) => ParagraphFeedback.fromJson(item)).toList(growable: false),
      revisedEssay: (map['revised_essay'] as String?) ?? '',
      rawAiResponse: (map['raw_ai_response'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(_asInt(map['created_at'])),
    );
  }
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List<dynamic>) return const [];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<dynamic> _decodeJsonList(Object? value) {
  if (value is List<dynamic>) return value;
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List<dynamic>) return decoded;
  }
  return const [];
}
