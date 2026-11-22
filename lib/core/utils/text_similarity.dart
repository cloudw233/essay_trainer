import 'dart:math' as math;

/// Produces a small, dependency-free token set for rough topic similarity.
///
/// English is compared by words; Chinese is compared by overlapping two-
/// character chunks. This is deliberately simple: it only needs to catch
/// batches that are obviously exploring the same angle, so the generator can
/// add a stronger "change direction" hint.
Set<String> similarityTokens(String text) {
  final lower = text.toLowerCase();
  final tokens = <String>{};

  for (final match in RegExp(r'[a-z0-9]+').allMatches(lower)) {
    final token = match.group(0);
    if (token != null && token.length > 2) tokens.add(token);
  }

  for (final match in RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF]+',
  ).allMatches(text)) {
    final run = match.group(0) ?? '';
    if (run.length == 1) {
      tokens.add(run);
      continue;
    }
    for (var i = 0; i < run.length - 1; i++) {
      tokens.add(run.substring(i, i + 2));
    }
  }

  return tokens;
}

double jaccardSimilarity(Set<String> first, Set<String> second) {
  if (first.isEmpty || second.isEmpty) return 0;
  final intersection = first.intersection(second).length;
  final union = first.union(second).length;
  return union == 0 ? 0 : intersection / union;
}

double textSimilarity(String first, String second) {
  return jaccardSimilarity(similarityTokens(first), similarityTokens(second));
}

/// A compact signature for one generated batch. Title and rationale carry the
/// angle; full prompt text is intentionally excluded because shared rubric
/// boilerplate would make unrelated prompts look similar.
Set<String> batchSignature(
  Iterable<({String title, String rationale})> prompts,
) {
  final buffer = StringBuffer();
  for (final prompt in prompts) {
    buffer
      ..write(prompt.title)
      ..write(' ')
      ..write(prompt.rationale)
      ..write(' ');
  }
  return similarityTokens(buffer.toString());
}

double batchSimilarity(
  Iterable<({String title, String rationale})> first,
  Iterable<({String title, String rationale})> second,
) {
  return jaccardSimilarity(batchSignature(first), batchSignature(second));
}

/// Exposed for diagnostics in tests: returns the longest shared keyword, if
/// one token accounts for the observed overlap.
String? strongestSharedToken(Set<String> first, Set<String> second) {
  final shared = first.intersection(second);
  if (shared.isEmpty) return null;
  return shared.reduce((a, b) => a.length >= b.length ? a : b);
}

/// Kept here so callers do not need `dart:math` just to format a percentage.
int similarityPercent(double value) =>
    (math.min(1, math.max(0, value)) * 100).round();
