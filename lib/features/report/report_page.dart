import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/draft_repository.dart';
import '../../core/database/report_repository.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/date_labels.dart';
import '../../core/utils/report_summary.dart';
import '../../models/dimension_score.dart';
import '../../models/enums.dart';
import '../../models/essay_draft.dart';
import '../../models/grading_report.dart';
import '../../models/paragraph_feedback.dart';
import '../../models/sentence_feedback.dart';
import '../../services/system_share.dart';

enum _EssayVersion { original, revised }

/// The finished review: prompt context, dimension scores, sentence/paragraph
/// feedback, and the full rewritten essay.
class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    required this.reportId,
    required this.reports,
    required this.drafts,
  });

  final String reportId;
  final ReportRepository reports;
  final DraftRepository drafts;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  GradingReport? _report;
  EssayDraft? _draft;
  bool _loading = true;
  Object? _error;
  _EssayVersion _version = _EssayVersion.revised;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.reports.findById(widget.reportId);
      if (!mounted) return;
      if (report == null) {
        setState(() {
          _loading = false;
          _error = StateError('report not found');
        });
        return;
      }
      final draft = await widget.drafts.findById(report.draftId);
      if (!mounted) return;
      setState(() {
        _report = report;
        _draft = draft;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String? _buildSummary() {
    final report = _report;
    if (report == null) return null;
    return buildReportSummary(report: report, draft: _draft);
  }

  Future<void> _copySummary() async {
    final summary = _buildSummary();
    if (summary == null) return;
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('报告摘要已复制。')));
  }

  Future<void> _shareSummary() async {
    final summary = _buildSummary();
    if (summary == null) return;
    final shared = await SystemShare.shareText(
      text: summary,
      subject: _draft?.title ?? '批改报告',
    );
    if (!mounted) return;
    if (shared) return;
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('系统分享不可用，报告摘要已复制。')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('批改报告'),
        actions: [
          IconButton(
            onPressed: _report == null ? null : _shareSummary,
            tooltip: '分享报告',
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _report == null ? null : _copySummary,
            tooltip: '复制报告摘要',
            icon: const Icon(Icons.copy_all_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const AppLoadingState();
    }
    if (_error != null || _report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text('找不到这份报告', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新读取'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final report = _report!;
    final draft = _draft;
    final semantics = theme.extension<AppSemanticColors>()!;
    final band = _bandFor(report.scoreRatio, semantics);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(label: draft?.language.label ?? '作文'),
                StatusPill(label: draft?.genre.label ?? '批改报告'),
                StatusPill(label: formatUpdatedAt(report.createdAt)),
              ],
            ),
            const SizedBox(height: 16),
            Text(draft?.title ?? '批改报告', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            _ScoreCard(report: report, band: band),
            if (draft != null && draft.hasPrompt) ...[
              const SizedBox(height: 16),
              _PromptContextCard(draft: draft),
            ],
            const SizedBox(height: 24),
            Text('分维度评分', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (
              var index = 0;
              index < report.dimensionScores.length;
              index++
            ) ...[
              _DimensionCard(score: report.dimensionScores[index]),
              if (index != report.dimensionScores.length - 1)
                const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('逐句诊断', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '${report.sentenceFeedback.length} 条',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (report.sentenceFeedback.isEmpty)
              const AppSurface(child: Text('这次没有逐句反馈。'))
            else
              for (
                var index = 0;
                index < report.sentenceFeedback.length;
                index++
              ) ...[
                _SentenceFeedbackCard(
                  feedback: report.sentenceFeedback[index],
                  semantics: semantics,
                ),
                if (index != report.sentenceFeedback.length - 1)
                  const SizedBox(height: 8),
              ],
            const SizedBox(height: 24),
            Text('逐段诊断', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (report.paragraphFeedback.isEmpty)
              const AppSurface(child: Text('这次没有逐段反馈。'))
            else
              for (
                var index = 0;
                index < report.paragraphFeedback.length;
                index++
              ) ...[
                _ParagraphFeedbackCard(
                  feedback: report.paragraphFeedback[index],
                ),
                if (index != report.paragraphFeedback.length - 1)
                  const SizedBox(height: 8),
              ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('全文升格', style: theme.textTheme.titleMedium),
                ),
                SegmentedButton<_EssayVersion>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _EssayVersion.original,
                      label: Text('原文'),
                    ),
                    ButtonSegment(
                      value: _EssayVersion.revised,
                      label: Text('升格版'),
                    ),
                  ],
                  selected: {_version},
                  onSelectionChanged: (selection) {
                    setState(() => _version = selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppSurface(
              color: theme.colorScheme.surfaceContainerLow,
              child: SelectableText(
                _version == _EssayVersion.original
                    ? (draft?.content ?? '原文未找到')
                    : report.revisedEssay,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (report.sentenceFeedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '先看题目是否回应，再看逐句建议；不必一次改完所有问题。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report, required this.band});

  final GradingReport report;
  final _ScoreBand band;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      color: band.container,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _scoreLabel(report.overallScore),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: band.onContainer,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${_scoreLabel(report.maxScore)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: band.onContainer.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const Spacer(),
              StatusPill(
                label: band.label,
                background: band.color,
                foreground: band.onColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: report.scoreRatio,
              minHeight: 8,
              color: band.color,
              backgroundColor: band.onContainer.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '总分来自各维度评分，具体失分原因见下方诊断。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: band.onContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptContextCard extends StatelessWidget {
  const _PromptContextCard({required this.draft});

  final EssayDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppSurface(
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('本次题目', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: SelectableText(
                draft.promptText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({required this.score});

  final DimensionScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = score.maxScore <= 0
        ? 0.0
        : (score.score / score.maxScore).clamp(0.0, 1.0);
    return AppSurface(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(score.name, style: theme.textTheme.titleSmall),
              ),
              Text(
                '${_scoreLabel(score.score)} / ${_scoreLabel(score.maxScore)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: ratio, minHeight: 6),
          ),
          const SizedBox(height: 8),
          Text(
            score.comment,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceFeedbackCard extends StatelessWidget {
  const _SentenceFeedbackCard({
    required this.feedback,
    required this.semantics,
  });

  final SentenceFeedback feedback;
  final AppSemanticColors semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _severityPalette(feedback.severity, semantics);

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.container,
            shape: BoxShape.circle,
          ),
          child: SeverityDot(color: palette.color),
        ),
        title: Text(
          feedback.originalText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              StatusPill(
                label: feedback.severity.label,
                background: palette.container,
                foreground: palette.onContainer,
              ),
              StatusPill(
                label: feedback.issueType.label,
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(feedback.comment, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '建议：${feedback.suggestion}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParagraphFeedbackCard extends StatelessWidget {
  const _ParagraphFeedbackCard({required this.feedback});

  final ParagraphFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 ${feedback.paragraphIndex + 1} 段',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(feedback.coherenceComment, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              feedback.contentComment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '建议：${feedback.suggestion}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBand {
  const _ScoreBand({
    required this.label,
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });

  final String label;
  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;
}

_ScoreBand _bandFor(double ratio, AppSemanticColors semantics) {
  if (ratio >= 0.85) {
    return _ScoreBand(
      label: '优秀',
      color: semantics.excellent,
      onColor: semantics.onExcellent,
      container: semantics.excellentContainer,
      onContainer: semantics.onExcellentContainer,
    );
  }
  if (ratio >= 0.7) {
    return _ScoreBand(
      label: '良好',
      color: semantics.good,
      onColor: semantics.onGood,
      container: semantics.goodContainer,
      onContainer: semantics.onGoodContainer,
    );
  }
  return _ScoreBand(
    label: '待提升',
    color: semantics.needsWork,
    onColor: semantics.onNeedsWork,
    container: semantics.needsWorkContainer,
    onContainer: semantics.onNeedsWorkContainer,
  );
}

class _SeverityPalette {
  const _SeverityPalette({
    required this.color,
    required this.container,
    required this.onContainer,
  });

  final Color color;
  final Color container;
  final Color onContainer;
}

_SeverityPalette _severityPalette(
  FeedbackSeverity severity,
  AppSemanticColors semantics,
) {
  return switch (severity) {
    FeedbackSeverity.critical => _SeverityPalette(
      color: semantics.critical,
      container: semantics.criticalContainer,
      onContainer: semantics.onCriticalContainer,
    ),
    FeedbackSeverity.minor => _SeverityPalette(
      color: semantics.minor,
      container: semantics.minorContainer,
      onContainer: semantics.onMinorContainer,
    ),
    FeedbackSeverity.suggestion => _SeverityPalette(
      color: semantics.suggestion,
      container: semantics.suggestionContainer,
      onContainer: semantics.onSuggestionContainer,
    ),
    FeedbackSeverity.highlight => _SeverityPalette(
      color: semantics.highlight,
      container: semantics.highlightContainer,
      onContainer: semantics.onHighlightContainer,
    ),
  };
}

String _scoreLabel(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
