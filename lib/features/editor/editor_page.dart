import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/draft_repository.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/word_counter.dart';
import '../../models/essay_draft.dart';
import '../../models/enums.dart';
import '../settings/api_key_controller.dart';

/// The focused writing surface.
///
/// Saving is local-only. Submitting saves the draft first and then opens the
/// grading page with the prompt snapshot already attached to the draft.
class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.drafts,
    required this.apiKeys,
    this.draftId,
    this.initialLanguage = EssayLanguage.chinese,
    this.initialGenre = EssayGenre.narrative,
  });

  final DraftRepository drafts;
  final ApiKeyController apiKeys;
  final String? draftId;
  final EssayLanguage initialLanguage;
  final EssayGenre initialGenre;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocus = FocusNode();

  late EssayLanguage _language;
  late EssayGenre _genre;
  String? _draftId;
  String _promptText = '';
  String? _promptPresetId;
  DateTime _createdAt = DateTime.now();
  DateTime? _savedAt;

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    _genre = widget.initialGenre;
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    _loadDraft();
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTextChanged)
      ..dispose();
    _contentController
      ..removeListener(_onTextChanged)
      ..dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted || _loading) return;
    setState(() {
      _count = countWords(_contentController.text, _language);
    });
  }

  Future<void> _loadDraft() async {
    if (widget.draftId == null) {
      setState(() {
        _loading = false;
        _count = 0;
      });
      return;
    }

    try {
      final draft = await widget.drafts.findById(widget.draftId!);
      if (!mounted) return;
      if (draft == null) {
        setState(() {
          _loading = false;
          _loadError = StateError('not found');
        });
        return;
      }

      _titleController.text = draft.title;
      _contentController.text = draft.content;
      setState(() {
        _draftId = draft.id;
        _language = draft.language;
        _genre = draft.genre;
        _createdAt = draft.createdAt;
        _savedAt = draft.updatedAt;
        _promptText = draft.promptText;
        _promptPresetId = draft.promptPresetId;
        _count = draft.wordCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  bool get _hasAnyContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty;

  bool get _meetsMinimum => _count >= _language.minimumWords;

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty && _meetsMinimum;

  Future<bool> _save({bool announce = true}) async {
    if (_saving) return false;
    if (!_hasAnyContent) {
      _showMessage('先写下标题或正文，再保存吧。');
      return false;
    }

    final now = DateTime.now();
    final trimmedTitle = _titleController.text.trim();
    final savedTitle = trimmedTitle.isEmpty ? '未命名草稿' : trimmedTitle;
    if (trimmedTitle.isEmpty) {
      _titleController.value = TextEditingValue(
        text: savedTitle,
        selection: TextSelection.collapsed(offset: savedTitle.length),
      );
    }

    setState(() => _saving = true);

    final draft = EssayDraft(
      id: _draftId ?? newLocalId('draft'),
      title: savedTitle,
      language: _language,
      genre: _genre,
      content: _contentController.text,
      wordCount: _count,
      createdAt: _createdAt,
      updatedAt: now,
      promptText: _promptText,
      promptPresetId: _promptPresetId,
    );

    try {
      await widget.drafts.save(draft);
      if (!mounted) return true;
      setState(() {
        _draftId = draft.id;
        _savedAt = now;
        _saving = false;
      });
      if (announce) _showMessage('草稿已保存到本机。');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _saving = false);
      _showMessage('保存失败，请稍后重试。');
      return false;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      if (_titleController.text.trim().isEmpty) {
        _showMessage('先给这篇作文起个标题。');
      } else {
        final remaining = _language.minimumWords - _count;
        _showMessage('还差 $remaining ${_language.countUnit} 才达到建议字数。');
      }
      return;
    }

    final saved = await _save(announce: false);
    if (!mounted || !saved || _draftId == null) return;

    if (!widget.apiKeys.hasKey) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          final theme = Theme.of(sheetContext);
          final scheme = theme.colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '先配置 DeepSeek API Key',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '草稿已经保存。配置 key 后才能提交 AI 批改；密钥只保存在设备安全存储中。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('返回编辑'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.go('/settings');
                      },
                      child: const Text('去设置'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    await context.push(
      '/grading?draftId=${Uri.encodeQueryComponent(_draftId!)}',
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('写作'),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : () => _save(),
            tooltip: '保存草稿',
            icon: const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(context, theme, scheme),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: _EditorBottomBar(
                language: _language,
                count: _count,
                canSubmit: _canSubmit,
                saving: _saving,
                compact: keyboardInset > 0,
                progress: (_count / _language.minimumWords).clamp(0.0, 1.0),
                onSave: () => _save(),
                onSubmit: _canSubmit ? _handleSubmit : null,
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text('找不到这篇草稿', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '它可能已经被删除。返回首页可以开始一篇新的作文。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回首页'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  icon: Icons.translate_rounded,
                  label: _language.label,
                ),
                StatusPill(icon: Icons.category_outlined, label: _genre.label),
                if (_savedAt != null)
                  StatusPill(
                    icon: Icons.check_circle_outline,
                    label: '已保存',
                    background: scheme.primaryContainer,
                    foreground: scheme.onPrimaryContainer,
                  ),
              ],
            ),
            if (_promptText.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _PromptReference(promptText: _promptText),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: theme.textTheme.headlineSmall,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _contentFocus.requestFocus(),
              decoration: InputDecoration(
                hintText: _language.titleHint,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocus,
                style: theme.textTheme.bodyLarge,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                scrollPadding: const EdgeInsets.only(bottom: 220),
                decoration: InputDecoration(
                  hintText: _language.bodyHint,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptReference extends StatelessWidget {
  const _PromptReference({required this.promptText});

  final String promptText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppSurface(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('作文题', style: theme.textTheme.labelLarge),
              const Spacer(),
              StatusPill(
                label: '只读',
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 72),
            child: SingleChildScrollView(
              child: SelectableText(
                promptText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorBottomBar extends StatelessWidget {
  const _EditorBottomBar({
    required this.language,
    required this.count,
    required this.canSubmit,
    required this.saving,
    required this.compact,
    required this.progress,
    required this.onSave,
    required this.onSubmit,
  });

  final EssayLanguage language;
  final int count;
  final bool canSubmit;
  final bool saving;
  final bool compact;
  final double progress;
  final VoidCallback onSave;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = language.minimumWords - count;
    final statusText = remaining > 0
        ? '还差 $remaining ${language.countUnit}'
        : '已达到建议字数';

    if (compact) {
      return Material(
        color: scheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$count / ${language.minimumWords} ${language.countUnit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: saving ? null : onSave,
                  tooltip: '保存草稿',
                  icon: const Icon(Icons.save_outlined),
                ),
                FilledButton(
                  onPressed: canSubmit && !saving ? onSubmit : null,
                  child: const Text('提交批改'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count / ${language.minimumWords} ${language.countUnit}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'AI 批改',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : onSave,
                      child: Text(saving ? '保存中…' : '保存草稿'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSubmit && !saving ? onSubmit : null,
                      child: const Text('提交批改'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
