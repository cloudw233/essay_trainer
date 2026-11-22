import 'package:essay_trainer/core/utils/word_counter.dart';
import 'package:essay_trainer/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countWords', () {
    test(
      'counts English words and keeps contractions and hyphens together',
      () {
        expect(
          countWords("It's a well-written essay.", EssayLanguage.english),
          4,
        );
      },
    );

    test('returns zero for empty or punctuation-only text', () {
      expect(countWords('', EssayLanguage.english), 0);
      expect(countWords('   \n\t', EssayLanguage.english), 0);
      expect(countWords('……，。！？', EssayLanguage.chinese), 0);
    });

    test('counts Chinese characters without whitespace or punctuation', () {
      expect(countWords('今天天气很好。', EssayLanguage.chinese), 6);
    });

    test('Chinese minimums and units match the writing brief', () {
      expect(EssayLanguage.chinese.minimumWords, 300);
      expect(EssayLanguage.chinese.countUnit, '字');
      expect(EssayLanguage.english.minimumWords, 60);
      expect(EssayLanguage.english.countUnit, '词');
    });
  });
}
