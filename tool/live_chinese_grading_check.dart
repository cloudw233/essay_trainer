// ignore_for_file: avoid_print

// Manual live check. Run with a real key, never commit the key:
// DEEPSEEK_API_KEY=... flutter test tool/live_chinese_grading_check.dart
import 'dart:io';

import 'package:essay_trainer/models/enums.dart';
import 'package:essay_trainer/models/essay_draft.dart';
import 'package:essay_trainer/services/grading_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  test(
    'live Chinese grading follows the 20/15/10/5 rubric',
    () async {
      expect(apiKey, isNotNull, reason: 'DEEPSEEK_API_KEY is required');
      final draft = EssayDraft(
        id: 'live-chinese-draft',
        title: '那一刻，我长大了',
        language: EssayLanguage.chinese,
        genre: EssayGenre.narrative,
        content:
            '那天傍晚，雨下得很急。我站在校门口的屋檐下，手里攥着一张不及格的数学卷子，不敢回家。'
            '父亲说好来接我，可等到人都散了，校门口只剩下一排湿漉漉的自行车。我忽然想起他最近总在加班，'
            '便决定自己走回去。路不远，却要经过一段没有路灯的小巷。我背着书包，听见雨点打在伞面上的声音，'
            '心里一遍遍想着那张卷子。走到巷口时，我看见一个熟悉的身影正踮着脚往这边张望。父亲没带伞，'
            '外套湿了一大片，手里却提着我最爱吃的糖炒栗子。他看见我，只说了一句：“怕你饿。”那一刻，'
            '我忽然觉得手里的卷子轻了许多。我接过栗子，第一次主动告诉他数学没考好。他没有责怪我，'
            '只把外套披在我肩上，说：“回家一起看看错在哪里。”雨还在下，可我不再害怕。那一路，'
            '我第一次觉得自己也可以为家里做点什么，也第一次明白，长大不是考出好成绩，而是学会理解另一个人的辛苦。',
        wordCount: 420,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        promptText: '请以“那一刻，我长大了”为题，写一篇不少于 600 字的记叙文。',
      );

      final report = await GradingService(timeout: const Duration(seconds: 110))
          .grade(
            apiKey: apiKey!,
            draft: draft,
            reportId: 'live-chinese-report',
            onAttempt: (attempt) => print('LIVE_CN_ATTEMPT=$attempt'),
          );

      print(
        'LIVE_CN_REPORT score=${report.overallScore}/${report.maxScore} '
        'dimensions=${report.dimensionScores.length} '
        'sentences=${report.sentenceFeedback.length} '
        'paragraphs=${report.paragraphFeedback.length}',
      );
      for (final dimension in report.dimensionScores) {
        print(
          'LIVE_CN_DIM ${dimension.name}: '
          '${dimension.score}/${dimension.maxScore}',
        );
      }
      final byName = {
        for (final dimension in report.dimensionScores)
          dimension.name: dimension,
      };
      expect(byName.keys, containsAll(['立意与内容', '结构与层次', '语言与表达', '书写与规范']));
      expect(byName['立意与内容']!.maxScore, 20);
      expect(byName['结构与层次']!.maxScore, 15);
      expect(byName['语言与表达']!.maxScore, 10);
      expect(byName['书写与规范']!.maxScore, 5);
      expect(report.dimensionScores.length, 4);
      expect(
        report.dimensionScores.fold<double>(0, (sum, d) => sum + d.score),
        closeTo(report.overallScore, 0.01),
      );
      expect(report.sentenceFeedback.length, greaterThanOrEqualTo(3));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
