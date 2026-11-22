import '../../models/enums.dart';
import '../../models/essay_draft.dart';
import '../../models/grading_report.dart';

/// A portable, human-readable report used by copy and system share.
///
/// Kept independent of Flutter so it can be tested without a widget tree.
String buildReportSummary({required GradingReport report, EssayDraft? draft}) {
  final title = draft?.title.trim();
  final buffer = StringBuffer()
    ..writeln('文衡 · 批改报告')
    ..writeln(title == null || title.isEmpty ? '批改报告' : title)
    ..writeln()
    ..writeln(
      '总分：${_scoreLabel(report.overallScore)} / '
      '${_scoreLabel(report.maxScore)}',
    );

  if (draft != null) {
    buffer.writeln(
      '${draft.language.label} · ${draft.genre.label} · '
      '${draft.language.minimumWords} ${draft.language.countUnit}起',
    );
  }

  buffer
    ..writeln()
    ..writeln('分维度评分');
  if (report.dimensionScores.isEmpty) {
    buffer.writeln('（无维度评分）');
  } else {
    for (final dimension in report.dimensionScores) {
      buffer
        ..writeln(
          '- ${dimension.name}：${_scoreLabel(dimension.score)} / '
          '${_scoreLabel(dimension.maxScore)}',
        )
        ..writeln('  ${dimension.comment}');
    }
  }

  buffer
    ..writeln()
    ..writeln('逐句诊断（${report.sentenceFeedback.length} 条）');
  if (report.sentenceFeedback.isEmpty) {
    buffer.writeln('（无逐句反馈）');
  } else {
    for (final item in report.sentenceFeedback) {
      buffer
        ..writeln(
          '${item.sentenceIndex + 1}. '
          '[${item.severity.label} / ${item.issueType.label}] '
          '${item.originalText}',
        )
        ..writeln('  ${item.comment}')
        ..writeln('  建议：${item.suggestion}');
    }
  }

  buffer
    ..writeln()
    ..writeln('逐段诊断（${report.paragraphFeedback.length} 段）');
  if (report.paragraphFeedback.isEmpty) {
    buffer.writeln('（无逐段反馈）');
  } else {
    for (final item in report.paragraphFeedback) {
      buffer
        ..writeln('第 ${item.paragraphIndex + 1} 段')
        ..writeln('  衔接：${item.coherenceComment}')
        ..writeln('  内容：${item.contentComment}')
        ..writeln('  建议：${item.suggestion}');
    }
  }

  buffer
    ..writeln()
    ..writeln('全文升格')
    ..writeln(report.revisedEssay);

  return buffer.toString().trimRight();
}

String _scoreLabel(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
