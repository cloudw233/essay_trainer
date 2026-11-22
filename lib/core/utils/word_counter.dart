import '../../models/enums.dart';

/// Counts words for English and characters for Chinese.
///
/// This deliberately does not count whitespace or punctuation. For Chinese,
/// only CJK ideographs are counted, matching how 作文格纸 counts a composition.
int countWords(String text, EssayLanguage language) {
  if (text.trim().isEmpty) return 0;

  return switch (language) {
    EssayLanguage.english => RegExp(
      r"[A-Za-z0-9]+(?:['’\-][A-Za-z0-9]+)*",
    ).allMatches(text).length,
    EssayLanguage.chinese => RegExp(
      r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
    ).allMatches(text).length,
  };
}

/// A compact, copy-ready count such as `128 词` or `412 字`.
String wordCountLabel(int count, EssayLanguage language) {
  return '$count ${language.countUnit}';
}
