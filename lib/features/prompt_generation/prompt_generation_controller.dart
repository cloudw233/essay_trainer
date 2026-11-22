import 'package:flutter/foundation.dart';

import '../../core/utils/text_similarity.dart';
import '../../models/enums.dart';
import '../../services/prompt_generation_service.dart';

/// App-level memory for candidate generations.
///
/// AI generation has a non-trivial miss rate. Keeping only a short, session-
/// level avoid-list is enough to make "换一批" useful without turning the
/// feature into a long, instruction-diluting chat.
class PromptGenerationController extends ChangeNotifier {
  PromptGenerationController({required PromptGenerationService service})
    : _service = service;

  static const _maxRecentBatches = 10;
  static const _similarityThreshold = 0.35;
  static const _autoAvoidHint = '请完全避开前两批的命题方向，换一个全新的切入点。';

  final PromptGenerationService _service;
  final List<List<String>> _recentBatchItems = [];
  Set<String>? _previousBatchSignature;
  bool _lastBatchWasSimilar = false;

  List<String> get avoidTitles =>
      _recentBatchItems.expand((items) => items).toList(growable: false);

  bool get lastBatchWasSimilar => _lastBatchWasSimilar;

  Future<PromptGenerationBatch> generate({
    required String apiKey,
    required EssayLanguage language,
    required EssayGenre genre,
    required PromptDifficulty difficulty,
    String extraHint = '',
    void Function(int attempt)? onAttempt,
  }) async {
    final hints = <String>[];
    if (extraHint.trim().isNotEmpty) hints.add(extraHint.trim());
    if (_lastBatchWasSimilar) hints.add(_autoAvoidHint);

    final batch = await _service.generate(
      apiKey: apiKey,
      request: PromptGenerationRequest(
        language: language,
        genre: genre,
        difficulty: difficulty,
        avoidTitles: avoidTitles,
        extraHint: hints.join('；'),
      ),
      onAttempt: onAttempt,
    );

    _record(batch);
    return batch;
  }

  void _record(PromptGenerationBatch batch) {
    final signature = batchSignature(
      batch.prompts.map(
        (prompt) => (title: prompt.title, rationale: prompt.rationale),
      ),
    );

    _lastBatchWasSimilar =
        _previousBatchSignature != null &&
        jaccardSimilarity(_previousBatchSignature!, signature) >=
            _similarityThreshold;
    _previousBatchSignature = signature;

    final items = batch.prompts
        .map((prompt) {
          final title = prompt.title.trim();
          final excerpt = prompt.promptText.length > 60
              ? '${prompt.promptText.substring(0, 60)}…'
              : prompt.promptText;
          return title.isEmpty ? excerpt : '$title — $excerpt';
        })
        .toList(growable: false);

    _recentBatchItems.add(items);
    if (_recentBatchItems.length > _maxRecentBatches) {
      _recentBatchItems.removeAt(0);
    }
    notifyListeners();
  }
}
