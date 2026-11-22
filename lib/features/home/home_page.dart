import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/draft_repository.dart';
import '../../core/database/preset_repository.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/utils/date_labels.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/word_counter.dart';
import '../../models/essay_draft.dart';
import '../../models/enums.dart';
import '../prompt_generation/prompt_generation_controller.dart';
import '../prompt_generation/prompt_generation_sheet.dart';
import '../settings/api_key_controller.dart';
import '../settings/writing_defaults_controller.dart';

/// The writing desk: choose a brief, start a draft, or continue recent work.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.drafts,
    required this.presets,
    required this.apiKeys,
    required this.writingDefaults,
    required this.promptGeneration,
  });

  final DraftRepository drafts;
  final PresetRepository presets;
  final ApiKeyController apiKeys;
  final WritingDefaultsController writingDefaults;
  final PromptGenerationController promptGeneration;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<EssayDraft> _recent = const [];
  bool _loading = true;
  Object? _loadError;

  EssayLanguage get _language => widget.writingDefaults.language;
  EssayGenre get _genre => widget.writingDefaults.genre;

  @override
  void initState() {
    super.initState();
    widget.writingDefaults.addListener(_onDefaultsChanged);
    _loadDrafts();
  }

  @override
  void dispose() {
    widget.writingDefaults.removeListener(_onDefaultsChanged);
    super.dispose();
  }

  void _onDefaultsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setLanguage(EssayLanguage language) async {
    try {
      await widget.writingDefaults.setLanguage(language);
    } catch (_) {
      _showMessage('默认语言保存失败，请稍后重试。');
    }
  }

  Future<void> _setGenre(EssayGenre genre) async {
    try {
      await widget.writingDefaults.setGenre(genre);
    } catch (_) {
      _showMessage('默认体裁保存失败，请稍后重试。');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDrafts() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final drafts = await widget.drafts.recent(limit: 5);
      if (!mounted) return;
      setState(() {
        _recent = drafts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _startWriting() async {
    final uri = Uri(
      path: '/editor',
      queryParameters: {'language': _language.name, 'genre': _genre.name},
    );
    await context.push(uri.toString());
    if (mounted) await _loadDrafts();
  }

  Future<void> _openDraft(EssayDraft draft) async {
    final uri = Uri(path: '/editor', queryParameters: {'draftId': draft.id});
    await context.push(uri.toString());
    if (mounted) await _loadDrafts();
  }

  Future<void> _openPromptGeneration() async {
    final selection = await showPromptGenerationSheet(
      context: context,
      controller: widget.promptGeneration,
      apiKeys: widget.apiKeys,
      presets: widget.presets,
      initialLanguage: _language,
      initialGenre: _genre,
    );
    if (selection == null || !mounted) return;

    final draft = selection.toDraft(
      draftId: newLocalId('draft'),
      now: DateTime.now(),
    );

    try {
      await widget.drafts.save(draft);
      if (!mounted) return;
      await context.push(
        '/editor?draftId=${Uri.encodeQueryComponent(draft.id)}',
      );
      if (mounted) await _loadDrafts();
    } catch (_) {
      _showMessage('题目已选定，但草稿创建失败，请重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDrafts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              pinned: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppMark(size: 34),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '文衡',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('今天，写点什么？', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          '把日常里值得记住的一瞬写下来。先完成，再慢慢写好。',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _HeroCard(
                          language: _language,
                          genre: _genre,
                          onStart: _startWriting,
                          onGeneratePrompt: _openPromptGeneration,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '最近草稿',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              _recent.isEmpty
                                  ? '从第一篇开始'
                                  : '共 ${_recent.length} 篇',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildRecent(context),
                        const SizedBox(height: 24),
                        _ApiKeyNotice(apiKeys: widget.apiKeys),
                        const SizedBox(height: 16),
                        _BriefCard(
                          language: _language,
                          genre: _genre,
                          onLanguageChanged: _setLanguage,
                          onGenreChanged: _setGenre,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecent(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(height: 120);
    }

    if (_loadError != null) {
      return AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('草稿暂时读取失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '请稍后重试。你的本地内容不会因此丢失。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadDrafts,
              icon: const Icon(Icons.refresh),
              label: const Text('重新读取'),
            ),
          ],
        ),
      );
    }

    if (_recent.isEmpty) {
      return _EmptyDrafts(onStart: _startWriting);
    }

    return Column(
      children: [
        for (var index = 0; index < _recent.length; index++) ...[
          _DraftCard(
            draft: _recent[index],
            onTap: () => _openDraft(_recent[index]),
          ),
          if (index != _recent.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.language,
    required this.genre,
    required this.onStart,
    required this.onGeneratePrompt,
  });

  final EssayLanguage language;
  final EssayGenre genre;
  final VoidCallback onStart;
  final VoidCallback onGeneratePrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: -8,
            child: ExcludeSemantics(
              child: Text(
                '文',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.08),
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  icon: Icons.edit_note,
                  label: '${language.label} · ${genre.label}',
                  background: scheme.primary,
                  foreground: scheme.onPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  '起笔，成文。',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '写作不是一次完成的事。先留下草稿，再让 AI 陪你看清可以更好的地方。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.86),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('开始写作'),
                    ),
                    TextButton.icon(
                      onPressed: onGeneratePrompt,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onPrimaryContainer,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('AI 出题'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({
    required this.language,
    required this.genre,
    required this.onLanguageChanged,
    required this.onGenreChanged,
  });

  final EssayLanguage language;
  final EssayGenre genre;
  final ValueChanged<EssayLanguage> onLanguageChanged;
  final ValueChanged<EssayGenre> onGenreChanged;

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
              Icon(Icons.tune_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Text('写作设置', style: theme.textTheme.titleMedium),
            ],
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
            selected: {language},
            onSelectionChanged: (selection) {
              onLanguageChanged(selection.first);
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
                  selected: genre == option,
                  onSelected: (_) => onGenreChanged(option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${genre.hint} · 不少于 ${language.minimumWords} ${language.countUnit}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyNotice extends StatelessWidget {
  const _ApiKeyNotice({required this.apiKeys});

  final ApiKeyController apiKeys;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: apiKeys,
      builder: (context, _) {
        if (apiKeys.isLoading || apiKeys.hasKey) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return AppSurface(
          color: scheme.secondaryContainer,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(Icons.key_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '还差一步：配置 DeepSeek API Key',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '密钥只保存在本机安全存储中，不写入代码或日志。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go('/settings'),
                child: const Text('去设置'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onTap});

  final EssayDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.isEmpty ? '未命名草稿' : draft.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${draft.language.label} · ${draft.genre.label} · '
                      '${wordCountLabel(draft.wordCount, draft.language)} · '
                      '${formatUpdatedAt(draft.updatedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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

class _EmptyDrafts extends StatelessWidget {
  const _EmptyDrafts({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppSurface(
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('还没有草稿', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '从上方选择一个语言与体裁，写下第一句。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('写下第一篇'),
          ),
        ],
      ),
    );
  }
}
