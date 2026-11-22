import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/draft_repository.dart';
import '../../core/database/report_repository.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/date_labels.dart';
import '../../models/enums.dart';
import '../../models/essay_draft.dart';
import '../../models/grading_report.dart';

/// All completed reports, newest first. Each row is swipe-to-delete with a
/// destructive surface colour taken from the active theme.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.reports, required this.drafts});

  final ReportRepository reports;
  final DraftRepository drafts;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<_HistoryEntry> _entries = const [];
  bool _loading = true;
  Object? _error;

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
      final reports = await widget.reports.all();
      final entries = <_HistoryEntry>[];
      for (final report in reports) {
        final draft = await widget.drafts.findById(report.draftId);
        entries.add(_HistoryEntry(report: report, draft: draft));
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  Future<void> _openReport(_HistoryEntry entry) async {
    await context.push(
      '/report?reportId=${Uri.encodeQueryComponent(entry.report.id)}',
    );
    if (mounted) await _load();
  }

  Future<bool> _confirmDelete(_HistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这份报告？'),
        content: const Text('删除后无法恢复；对应的草稿不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    try {
      await widget.reports.delete(entry.report.id);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试。')));
      return false;
    }
  }

  void _removeEntry(_HistoryEntry entry) {
    if (!mounted) return;
    setState(() {
      _entries = _entries
          .where((item) => item.report.id != entry.report.id)
          .toList(growable: false);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已删除「${entry.title}」。')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _buildBody(theme, scheme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme scheme) {
    if (_loading) {
      return const AppLoadingState();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('历史记录读取失败', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '按时间倒序排列。向左滑动可以删除报告。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_entries.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '共 ${_entries.length} 份',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_entries.isEmpty)
            AppSurface(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_edu_outlined,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('还没有批改记录', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '完成一次 AI 批改后，分维度评分、逐句建议和全文升格都会保存在本机。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('去首页开始写作'),
                  ),
                ],
              ),
            )
          else
            for (final entry in _entries) ...[
              Dismissible(
                key: ValueKey(entry.report.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(entry),
                onDismissed: (_) => _removeEntry(entry),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '删除',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                child: _ReportHistoryCard(
                  entry: entry,
                  onTap: () => _openReport(entry),
                ),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '报告与草稿只保存在设备本地。卸载应用会一并删除，重要内容请及时复制。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({required this.report, required this.draft});

  final GradingReport report;
  final EssayDraft? draft;

  String get title {
    final value = draft?.title.trim();
    return value == null || value.isEmpty ? '未命名作文' : value;
  }
}

class _ReportHistoryCard extends StatelessWidget {
  const _ReportHistoryCard({required this.entry, required this.onTap});

  final _HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final report = entry.report;
    final ratio = report.scoreRatio;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _scoreLabel(report.overallScore),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '/ ${_scoreLabel(report.maxScore)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.draft?.language.label ?? '作文'} · '
                      '${report.dimensionScores.length} 个维度 · '
                      '${report.sentenceFeedback.length} 条逐句反馈 · '
                      '${formatUpdatedAt(report.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _scoreLabel(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
