import 'package:flutter/material.dart';

import '../../core/database/preset_repository.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/id_generator.dart';
import '../../models/enums.dart';
import '../../models/prompt_preset.dart';

/// A single list for AI-generated prompts the user saved and manually created
/// prompts. The source pill is the only distinction; both are editable/deletable
/// through the same repository.
class PresetLibraryPage extends StatefulWidget {
  const PresetLibraryPage({super.key, required this.presets});

  final PresetRepository presets;

  @override
  State<PresetLibraryPage> createState() => _PresetLibraryPageState();
}

class _PresetLibraryPageState extends State<PresetLibraryPage> {
  List<PromptPreset> _items = const [];
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
      final items = await widget.presets.all();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<bool> _confirmDelete(PromptPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这道预设？'),
        content: const Text('已保存的草稿不会受影响；草稿里的题目快照会继续保留。'),
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
    return confirmed == true && mounted;
  }

  void _removePresetFromList(PromptPreset preset) {
    setState(
      () => _items = _items.where((item) => item.id != preset.id).toList(),
    );
  }

  Future<void> _deleteFromStorage(PromptPreset preset) async {
    try {
      await widget.presets.delete(preset.id);
      if (mounted) _showMessage('已删除预设。');
    } catch (_) {
      if (!mounted) return;
      _showMessage('删除失败，请稍后重试。');
      await _load();
    }
  }

  Future<void> _deleteConfirmed(PromptPreset preset) async {
    _removePresetFromList(preset);
    await _deleteFromStorage(preset);
  }

  Future<void> _delete(PromptPreset preset) async {
    if (!await _confirmDelete(preset) || !mounted) return;
    await _deleteConfirmed(preset);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createManual() async {
    final preset = await showModalBottomSheet<PromptPreset>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ManualPresetSheet(),
    );
    if (preset == null || !mounted) return;
    try {
      await widget.presets.save(preset);
      if (!mounted) return;
      setState(() {
        _items = [..._items, preset]..sort((a, b) => a.name.compareTo(b.name));
      });
      _showMessage('手动预设已保存。');
    } catch (_) {
      if (!mounted) return;
      _showMessage('保存预设失败，请稍后重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('题目预设'),
        actions: [
          IconButton(
            onPressed: _createManual,
            tooltip: '新建手动预设',
            icon: const Icon(Icons.add),
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
                Text('预设读取失败', style: theme.textTheme.titleMedium),
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
          Text(
            'AI 收藏和手动创建的题目都保存在这里，用来源标签区分。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            AppSurface(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.bookmarks_outlined,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text('还没有收藏的题目', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '在 AI 出题候选卡片上点「收藏」，题目就会出现在这里。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _createManual,
                    icon: const Icon(Icons.add),
                    label: const Text('新建预设'),
                  ),
                ],
              ),
            )
          else
            for (final preset in _items) ...[
              Dismissible(
                key: ValueKey('preset-${preset.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(preset),
                onDismissed: (_) {
                  _removePresetFromList(preset);
                  _deleteFromStorage(preset);
                },
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
                child: _PresetCard(
                  preset: preset,
                  onDelete: () => _delete(preset),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.onDelete});

  final PromptPreset preset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                preset.source == PromptSource.ai
                    ? Icons.auto_awesome_outlined
                    : Icons.edit_note_outlined,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name.isEmpty ? '未命名预设' : preset.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(
                        label: preset.source.label,
                        background: preset.source == PromptSource.ai
                            ? scheme.tertiaryContainer
                            : scheme.surfaceContainerHighest,
                        foreground: preset.source == PromptSource.ai
                            ? scheme.onTertiaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      StatusPill(label: preset.language.label),
                      StatusPill(label: preset.genre.label),
                      if (preset.suggestedWordCount > 0)
                        StatusPill(
                          label:
                              '${preset.suggestedWordCount} ${preset.language.countUnit}',
                        ),
                    ],
                  ),
                  if (preset.promptText.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      preset.promptText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (preset.rationale.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      preset.rationale,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: '删除预设',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualPresetSheet extends StatefulWidget {
  const _ManualPresetSheet();

  @override
  State<_ManualPresetSheet> createState() => _ManualPresetSheetState();
}

class _ManualPresetSheetState extends State<_ManualPresetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _prompt = TextEditingController();
  final _wordCount = TextEditingController();
  EssayLanguage _language = EssayLanguage.chinese;
  EssayGenre _genre = EssayGenre.other;

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _wordCount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final preset = PromptPreset(
      id: newLocalId('preset'),
      name: _name.text.trim(),
      language: _language,
      genre: _genre,
      promptText: _prompt.text.trim(),
      rubricText: '',
      maxScore: _language.defaultMaxScore,
      createdAt: now,
      source: PromptSource.manual,
      difficulty: PromptDifficulty.standard,
      suggestedWordCount: int.tryParse(_wordCount.text.trim()) ?? 0,
      rationale: '',
    );
    Navigator.of(context).pop(preset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('新建手动预设', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '手动题也会进入同一个预设库，来源标记为「手动创建」。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '预设名称'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请填写名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prompt,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '完整题目与写作要求',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请填写题目' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EssayLanguage>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: '语言'),
              items: [
                for (final value in EssayLanguage.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _language = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EssayGenre>(
              initialValue: _genre,
              decoration: const InputDecoration(labelText: '体裁'),
              items: [
                for (final value in EssayGenre.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _genre = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wordCount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '建议字数（可选）',
                hintText: '例如 800',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final count = int.tryParse(value.trim());
                return count == null || count <= 0 ? '请输入正整数' : null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存预设')),
          ],
        ),
      ),
    );
  }
}
