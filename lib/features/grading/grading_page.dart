import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/draft_repository.dart';
import '../../core/database/report_repository.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/id_generator.dart';
import '../../models/essay_draft.dart';
import '../../services/grading_service.dart';
import '../settings/api_key_controller.dart';

/// Runs one grading request and hands the saved report to the report page.
class GradingPage extends StatefulWidget {
  const GradingPage({
    super.key,
    required this.draftId,
    required this.drafts,
    required this.reports,
    required this.apiKeys,
    required this.gradingService,
  });

  final String draftId;
  final DraftRepository drafts;
  final ReportRepository reports;
  final ApiKeyController apiKeys;
  final GradingService gradingService;

  @override
  State<GradingPage> createState() => _GradingPageState();
}

class _GradingPageState extends State<GradingPage> {
  static const _stepLabels = ['题干拆解', '逐句精修', '逐段诊断', '全文评分与升格'];

  EssayDraft? _draft;
  bool _loading = true;
  bool _grading = false;
  bool _needsKey = false;
  Object? _error;
  String? _rawResponse;
  int _attempt = 1;
  int _elapsedSeconds = 0;
  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await widget.drafts.findById(widget.draftId);
      if (!mounted) return;
      if (draft == null) {
        setState(() {
          _loading = false;
          _error = StateError('draft not found');
        });
        return;
      }
      _draft = draft;
      setState(() => _loading = false);
      if (!widget.apiKeys.hasKey) {
        setState(() {
          _needsKey = true;
          _error = '请先在设置页配置 DeepSeek API Key。';
        });
        return;
      }
      await _runGrading(draft);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _runGrading(EssayDraft draft) async {
    _timer?.cancel();
    setState(() {
      _grading = true;
      _error = null;
      _rawResponse = null;
      _needsKey = false;
      _attempt = 1;
      _elapsedSeconds = 0;
      _stage = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
        _stage = _stageForElapsed(_elapsedSeconds);
      });
    });

    try {
      final report = await widget.gradingService.grade(
        apiKey: widget.apiKeys.apiKey!,
        draft: draft,
        reportId: newLocalId('report'),
        onAttempt: (attempt) {
          if (!mounted) return;
          setState(() => _attempt = attempt);
        },
      );
      _timer?.cancel();
      if (!mounted) return;

      try {
        await widget.reports.save(report);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _grading = false;
          _error = '报告已生成，但写入本地数据库失败。请重试。';
          _rawResponse = report.rawAiResponse;
        });
        return;
      }

      if (!mounted) return;
      setState(() => _grading = false);
      context.pushReplacement(
        '/report?reportId=${Uri.encodeQueryComponent(report.id)}',
      );
    } on GradingServiceException catch (error) {
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _grading = false;
        _error = error.message;
        _rawResponse = error.rawResponse;
      });
    } catch (error) {
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _grading = false;
        _error = '批改失败，请稍后重试。';
      });
    }
  }

  int _stageForElapsed(int seconds) {
    if (seconds < 4) return 0;
    if (seconds < 10) return 1;
    if (seconds < 16) return 2;
    return 3;
  }

  Future<void> _copyRaw() async {
    final raw = _rawResponse;
    if (raw == null || raw.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('原始响应已复制。')));
  }

  void _goToSettings() {
    context.go('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 批改')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_grading) {
      return _GradingProgress(
        attempt: _attempt,
        elapsedSeconds: _elapsedSeconds,
        stage: _stage,
        steps: _stepLabels,
      );
    }

    final error = _error;
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          AppSurface(
            color: theme.colorScheme.errorContainer,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _needsKey ? '还没有配置 API Key' : '这次批改没有完成',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_rawResponse != null && _rawResponse!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('查看原始响应'),
              subtitle: const Text('格式校验失败时可用于复制反馈'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    _rawResponse!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_needsKey)
            FilledButton.icon(
              onPressed: _goToSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('去设置 API Key'),
            )
          else
            FilledButton.icon(
              onPressed: _draft == null ? null : () => _runGrading(_draft!),
              icon: const Icon(Icons.refresh),
              label: const Text('重新批改'),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('返回编辑'),
          ),
          if (_rawResponse != null && _rawResponse!.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _copyRaw,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('复制原始响应'),
            ),
          ],
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('请选择一篇达到字数的作文提交批改。', style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

class _GradingProgress extends StatelessWidget {
  const _GradingProgress({
    required this.attempt,
    required this.elapsedSeconds,
    required this.stage,
    required this.steps,
  });

  final int attempt;
  final int elapsedSeconds;
  final int stage;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.auto_awesome, color: scheme.onTertiaryContainer),
        ),
        const SizedBox(height: 18),
        Text('正在批改这篇作文', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          attempt == 1
              ? 'AI 正在审题、逐句精修、逐段诊断并评分。通常需要 20–60 秒。'
              : '第一次结果未通过结构校验，正在重新整理批改结果。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '已等待 $minutes:$seconds',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppSurface(
          color: scheme.surfaceContainerLow,
          child: Column(
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                _StepRow(
                  label: steps[index],
                  state: index < stage
                      ? _StepState.done
                      : index == stage
                      ? _StepState.active
                      : _StepState.pending,
                ),
                if (index != steps.length - 1) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '完成后会自动保存报告，并进入分维度评分与逐句诊断页面。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (state) {
      _StepState.done => scheme.primary,
      _StepState.active => scheme.primary,
      _StepState.pending => scheme.onSurfaceVariant,
    };
    final icon = switch (state) {
      _StepState.done => Icons.check_circle_outline,
      _StepState.active => Icons.radio_button_checked,
      _StepState.pending => Icons.radio_button_unchecked,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: state == _StepState.pending
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
                fontWeight: state == _StepState.active
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
          if (state == _StepState.active)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
