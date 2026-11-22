/// A score for one rubric dimension (for example, 内容 or 语言).
class DimensionScore {
  const DimensionScore({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.comment,
  });

  final String name;
  final double score;
  final double maxScore;
  final String comment;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'score': score,
      'maxScore': maxScore,
      'comment': comment,
    };
  }

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      name: (json['name'] as String?) ?? '',
      score: _asDouble(json['score']),
      maxScore: _asDouble(json['maxScore'], fallback: 10),
      comment: (json['comment'] as String?) ?? '',
    );
  }
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
