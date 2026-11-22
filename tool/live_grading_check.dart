// ignore_for_file: avoid_print

// Manual live check. Run with a real key, never commit the key:
// DEEPSEEK_API_KEY=... flutter test tool/live_grading_check.dart
import 'dart:io';

import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/models/essay_draft.dart';
import 'package:essay_trainer/services/grading_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  test(
    'live grading returns a complete report',
    () async {
      expect(apiKey, isNotNull, reason: 'DEEPSEEK_API_KEY is required');
      final draft = EssayDraft(
        id: 'live-draft',
        title: 'A Small Decision',
        language: EssayLanguage.english,
        genre: EssayGenre.narrative,
        content:
            'The morning was cold and the street was empty. I stood at the corner, holding the letter. '
            'For a long time I did not move. I thought about the warm kitchen behind me and the empty '
            'classroom waiting ahead. My hands were shaking, so I put the letter in my pocket. Then I '
            'turned left, toward the school. The street was still quiet, but I was no longer afraid. '
            'When I reached the gate, I saw my teacher waving from the window. I walked in and told her '
            'that I was ready to try again. That small decision changed the rest of my day.',
        wordCount: 112,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        promptText:
            'Write a narrative about a small decision that changed your day. At least 120 words. '
            'Use specific details and a clear turning point.',
      );

      final report = await GradingService(timeout: const Duration(seconds: 110))
          .grade(
            apiKey: apiKey!,
            draft: draft,
            reportId: 'live-report',
            onAttempt: (attempt) => print('LIVE_ATTEMPT=$attempt'),
          );

      print(
        'LIVE_REPORT score=${report.overallScore}/${report.maxScore} '
        'dimensions=${report.dimensionScores.length} '
        'sentences=${report.sentenceFeedback.length} '
        'paragraphs=${report.paragraphFeedback.length} '
        'revised_chars=${report.revisedEssay.length}',
      );
      for (final dimension in report.dimensionScores) {
        print(
          'LIVE_DIMENSION ${dimension.name}: '
          '${dimension.score}/${dimension.maxScore}',
        );
      }
      expect(report.maxScore, 25);
      expect(report.dimensionScores, isNotEmpty);
      expect(report.sentenceFeedback.length, greaterThanOrEqualTo(3));
      expect(report.paragraphFeedback, isNotEmpty);
      expect(report.revisedEssay.trim(), isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
