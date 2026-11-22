import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/preset_repository.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/id_generator.dart';
import '../../models/enums.dart';
import '../../models/generated_prompt.dart';
import '../../models/prompt_preset.dart';
import '../../services/prompt_generation_service.dart';
import '../settings/api_key_controller.dart';
import 'prompt_generation_controller.dart';

/// Opens the candidate-based AI prompt flow.
///
/// The product decision is intentional: single-shot AI prompt quality is
/// usually estimated at roughly 85–90%, so one or two prompts in every ten
/// need human judgement, and the app cannot know which ones. Showing three
/// candidates and requiring an explicit "选这道" keeps the user in control and
/// prevents a generated prompt from silently replacing the current essay topic.
Future<PromptSelection?> showPromptGenerationSheet({
  required BuildContext context,
  required PromptGenerationController controller,
  required ApiKeyController apiKeys,
  required PresetRepository presets,
  required EssayLanguage initialLanguage,
  required EssayGenre initialGenre,
}) {
  return showModalBottomSheet<PromptSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.92,
        child: PromptGenerationSheet(
          controller: controller,
          apiKeys: apiKeys,
          presets: presets,
          initialLanguage: initialLanguage,
          initialGenre: initialGenre,
        ),
      );
    },
  );
}

class PromptGenerationSheet extends StatefulWidget {
  const PromptGenerationSheet({
    super.key,
    required this.controller,
    required this.apiKeys,
    required this.presets,
    required this.initialLanguage,
    required this.initialGenre,
  });

  final PromptGenerationController controller;
  final ApiKeyController apiKeys;
  final PresetRepository presets;
  final EssayLanguage initialLanguage;
  final EssayGenre initialGenre;

  @override
  State<PromptGenerationSheet> createState() => _PromptGenerationSheetState();
}

enum _SheetStage { setup, loading, candidates, error }

class _PromptGenerationSheetState extends State<PromptGenerationSheet> {
  final TextEditingController _hintController = TextEditingController();
  final TextEditingController _manualController = TextEditingController();
  final Map<String, String> _savedPresetIds = {};

  late EssayLanguage _language;
  late EssayGenre _genre;
  PromptDifficulty _difficulty = PromptDifficulty.standard;
  _SheetStage _stage = _SheetStage.setup;
  PromptGenerationBatch? _batch;
  String? _error;
  int _attempt = 1;
  bool _showManualInput = false;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    _genre = widget.initialGenre;
  }

  @override
  void dispose() {
    _hintController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final apiKey = widget.apiKeys.apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      _showMessage('请先在设置页配置 DeepSeek API Key。');
      return;
    }

    setState(() {
      _stage = _SheetStage.loading;
      _error = null;
      _attempt = 1;
    });

    try {
      final batch = await widget.controller.generate(
        apiKey: apiKey,
        language: _language,
        genre: _genre,
        difficulty: _difficulty,
        extraHint: _hintController.text,
        onAttempt: (attempt) {
          if (!mounted) return;
          setState(() => _attempt = attempt);
        },
      );
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _stage = _SheetStage.candidates;
      });
    } on PromptGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _stage = _SheetStage.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '生成题目失败，请稍后重试或手动输入题目。';
        _stage = _SheetStage.error;
      });
    }
  }

  Future<void> _favorite(GeneratedPrompt prompt) async {
    if (_savedPresetIds.containsKey(prompt.id) || _favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      final preset = PromptPreset.fromGenerated(
        prompt,
        id: newLocalId('preset'),
        createdAt: DateTime.now(),
      );
      await widget.presets.save(preset);
      if (!mounted) return;
      setState(() => _savedPresetIds[prompt.id] = preset.id);
      _showMessage('已收藏，可在「设置 → 题目预设」查看。');
    } catch (_) {
      if (!mounted) return;
      _showMessage('收藏失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  void _select(GeneratedPrompt prompt) {
    Navigator.of(
      context,
    ).pop(prompt.toSelection(promptPresetId: _savedPresetIds[prompt.id]));
  }

  void _selectManual() {
    final text = _manualController.text.trim();
    if (text.isEmpty) {
      _showMessage('先把完整题目和写作要求写下来。');
      return;
    }
    Navigator.of(context).pop(
      PromptSelection(
        title: '手动命题',
        promptText: text,
        language: _language,
        genre: _genre,
        suggestedWordCount: _language.minimumWords,
      ),
    );
  }

  void _goToSettings() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/settings');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI 出题', style: theme.textTheme.titleLarge),
                      Text(
                        '先生成 3 道候选，再由你决定写哪一道',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildStage(theme, scheme)),
        ],
      ),
    );
  }

  Widget _buildStage(ThemeData theme, ColorScheme scheme) {
    return switch (_stage) {
      _SheetStage.setup => _buildSetup(theme, scheme),
      _SheetStage.loading => _buildLoading(theme, scheme),
      _SheetStage.candidates => _buildCandidates(theme, scheme),
      _SheetStage.error => _buildError(theme, scheme),
    };
  }

  Widget _buildSetup(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            children: [
              if (!widget.apiKeys.hasKey) ...[
                AppSurface(
                  color: scheme.secondaryContainer,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.key_outlined,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '需要先配置 DeepSeek API Key 才能生成候选题目。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToSettings,
                        child: const Text('去设置'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('这次想练什么？', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'AI 命题会给出候选，但也会偶尔套作或跑偏。读题、换一批、手动改，都由你决定。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '语言',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<EssayLanguage>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EssayLanguage.chinese,
                    icon: Icon(Icons.menu_book_outlined),
                    label: Text('语文'),
                  ),
                  ButtonSegment(
                    value: EssayLanguage.english,
                    icon: Icon(Icons.translate_rounded),
                    label: Text('英语'),
                  ),
                ],
                selected: {_language},
                onSelectionChanged: (selection) {
                  setState(() => _language = selection.first);
                },
              ),
              const SizedBox(height: 16),
              Text(
                '体裁',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in EssayGenre.values)
                    FilterChip(
                      label: Text(option.label),
                      selected: _genre == option,
                      onSelected: (_) => setState(() => _genre = option),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '难度',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PromptDifficulty>(
                showSelectedIcon: false,
                segments: [
                  for (final option in PromptDifficulty.values)
                    ButtonSegment(value: option, label: Text(option.label)),
                ],
                selected: {_difficulty},
                onSelectionChanged: (selection) {
                  setState(() => _difficulty = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _difficulty.hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _showManualInput = !_showManualInput);
                  },
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('手动输入题目'),
                ),
              ),
              if (_showManualInput) _buildManualFallback(theme, scheme),
            ],
          ),
        ),
        _SetupFooter(
          hintController: _hintController,
          canGenerate: widget.apiKeys.hasKey,
          onGenerate: _generate,
        ),
      ],
    );
  }

  Widget _buildLoading(ThemeData theme, ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text('正在出题', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          _attempt == 1 ? '正在生成 3 道候选题目，并进行格式校验…' : '第一次输出未通过格式校验，正在重新生成…',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        for (var index = 0; index < 3; index++) ...[
          const _SkeletonPromptCard(),
          if (index != 2) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildCandidates(ThemeData theme, ColorScheme scheme) {
    final batch = _batch;
    if (batch == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('候选题目', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '选中一道才会进入写作。AI 不会自动替换你的当前作文题。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _stage == _SheetStage.loading ? null : _generate,
              icon: const Icon(Icons.refresh),
              label: const Text('换一批'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(label: _language.label),
            StatusPill(label: _genre.label),
            StatusPill(label: _difficulty.label),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < batch.prompts.length; index++) ...[
          _CandidateCard(
            prompt: batch.prompts[index],
            index: index,
            saved: _savedPresetIds.containsKey(batch.prompts[index].id),
            favoriteBusy: _favoriteBusy,
            onSelect: () => _select(batch.prompts[index]),
            onFavorite: () => _favorite(batch.prompts[index]),
          ),
          if (index != batch.prompts.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _stage = _SheetStage.setup),
            icon: const Icon(Icons.tune),
            label: const Text('调整参数'),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme scheme) {
    return ListView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        AppSurface(
          color: scheme.errorContainer,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '这次没有拿到可用题目',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error ?? '格式校验未通过。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh),
            label: const Text('再试一次'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _stage = _SheetStage.setup),
            child: const Text('调整参数'),
          ),
        ),
        const SizedBox(height: 16),
        _buildManualFallback(theme, scheme),
      ],
    );
  }

  Widget _buildManualFallback(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('手动输入题目', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '如果你觉得 AI 的题都不合适，可以直接把完整题目粘贴进来，仍然会作为本稿的题目快照保存。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _manualController,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '完整题目与写作要求',
            hintText: '材料、任务、字数下限和文体限定……',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _selectManual,
            icon: const Icon(Icons.edit_note),
            label: const Text('用这道手动题目开始写作'),
          ),
        ),
      ],
    );
  }
}

class _SetupFooter extends StatelessWidget {
  const _SetupFooter({
    required this.hintController,
    required this.canGenerate,
    required this.onGenerate,
  });

  final TextEditingController hintController;
  final bool canGenerate;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hintController,
              maxLines: 1,
              maxLength: 120,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '可选方向提示',
                hintText: '例如：贴近科技伦理、偏书信体、写校园生活',
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canGenerate ? onGenerate : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成 3 道候选'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.prompt,
    required this.index,
    required this.saved,
    required this.favoriteBusy,
    required this.onSelect,
    required this.onFavorite,
  });

  final GeneratedPrompt prompt;
  final int index;
  final bool saved;
  final bool favoriteBusy;
  final VoidCallback onSelect;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayTitle = prompt.title.trim().isEmpty
        ? '材料作文 · 候选 ${index + 1}'
        : prompt.title.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(displayTitle, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: '候选 ${index + 1}',
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(label: prompt.genre.label),
                StatusPill(label: prompt.difficulty.label),
                StatusPill(
                  label:
                      '建议 ${prompt.suggestedWordCount} ${prompt.language.countUnit}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prompt.promptText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (prompt.rationale.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      prompt.rationale,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: onSelect, child: const Text('选这道')),
                OutlinedButton.icon(
                  onPressed: saved || favoriteBusy ? null : onFavorite,
                  icon: Icon(
                    saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                  ),
                  label: Text(saved ? '已收藏' : '收藏'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPromptCard extends StatelessWidget {
  const _SkeletonPromptCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double widthFactor, double height) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(0.55, 16),
            const SizedBox(height: 12),
            bar(0.9, 11),
            const SizedBox(height: 8),
            bar(0.75, 11),
            const SizedBox(height: 16),
            bar(0.35, 12),
          ],
        ),
      ),
    );
  }
}
