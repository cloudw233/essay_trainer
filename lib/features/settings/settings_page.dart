import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_widgets.dart';
import '../../core/theme/dynamic_color_scope.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/enums.dart';
import '../../services/deepseek_service.dart';
import 'api_key_controller.dart';
import 'writing_defaults_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    required this.apiKeys,
    required this.deepSeekService,
    required this.writingDefaults,
  });

  final ThemeController themeController;
  final ApiKeyController apiKeys;
  final DeepSeekService deepSeekService;
  final WritingDefaultsController writingDefaults;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _keyController;
  bool _obscureKey = true;
  bool _saving = false;
  bool _testing = false;
  String? _testReply;
  String? _testError;
  Duration? _latency;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.apiKeys.apiKey ?? '');
    _keyController.addListener(_onKeyChanged);
    widget.apiKeys.addListener(_syncFromController);
    _syncFromController();
  }

  @override
  void dispose() {
    widget.apiKeys.removeListener(_syncFromController);
    _keyController
      ..removeListener(_onKeyChanged)
      ..dispose();
    super.dispose();
  }

  void _onKeyChanged() {
    if (!mounted) return;
    setState(() {
      _testReply = null;
      _testError = null;
      _latency = null;
    });
  }

  void _syncFromController() {
    final key = widget.apiKeys.apiKey;
    if (key != null && key != _keyController.text) {
      _keyController.text = key;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _showMessage('请先填写 API Key。');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.apiKeys.save(key);
      if (!mounted) return;
      setState(() {
        _testError = null;
        _testReply = null;
        _latency = null;
      });
      _showMessage('API Key 已保存到设备安全存储。');
    } catch (error) {
      if (!mounted) return;
      _showMessage('保存失败，请检查设备安全存储是否可用。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _showMessage('请先填写 API Key，再测试连接。');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _testReply = null;
      _testError = null;
      _latency = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final reply = await widget.deepSeekService.testConnection(key);
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _testReply = reply;
        _latency = stopwatch.elapsed;
      });
    } on DeepSeekServiceException catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() => _testError = error.message);
    } catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() => _testError = '连接失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clearKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('移除 API Key？'),
          content: const Text('移除后，DeepSeek 批改将无法使用。草稿与历史记录不会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.apiKeys.clear();
      _keyController.clear();
      if (!mounted) return;
      setState(() {
        _testReply = null;
        _testError = null;
        _latency = null;
      });
      _showMessage('已从安全存储中移除 API Key。');
    } catch (error) {
      if (!mounted) return;
      _showMessage('移除失败，请稍后重试。');
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    try {
      await widget.themeController.setMode(mode);
    } catch (error) {
      if (!mounted) return;
      _showMessage('主题设置保存失败，请稍后重试。');
    }
  }

  Future<void> _setDefaultLanguage(EssayLanguage language) async {
    try {
      await widget.writingDefaults.setLanguage(language);
    } catch (_) {
      if (!mounted) return;
      _showMessage('默认语言保存失败，请稍后重试。');
    }
  }

  Future<void> _setDefaultGenre(EssayGenre genre) async {
    try {
      await widget.writingDefaults.setGenre(genre);
    } catch (_) {
      if (!mounted) return;
      _showMessage('默认体裁保存失败，请稍后重试。');
    }
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
    final dynamicActive = DynamicColorScope.isActiveOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('写作环境', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '让界面、密钥和默认偏好都待在你顺手的位置。',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                AppSurface(
                  color: scheme.surfaceContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '外观',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          StatusPill(
                            icon: dynamicActive
                                ? Icons.auto_awesome
                                : Icons.format_paint_outlined,
                            label: dynamicActive ? '动态取色' : '种子色回退',
                            background: dynamicActive
                                ? scheme.tertiaryContainer
                                : scheme.surfaceContainerHighest,
                            foreground: dynamicActive
                                ? scheme.onTertiaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dynamicActive
                            ? '已跟随系统壁纸生成 Material You 配色。'
                            : '当前设备未提供动态壁纸配色，使用低饱和墨绿种子色。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '显示模式',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: widget.themeController,
                        builder: (context, _) {
                          return SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('跟随系统'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('浅色'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('深色'),
                              ),
                            ],
                            selected: {widget.themeController.mode},
                            onSelectionChanged: (selection) {
                              _setThemeMode(selection.first);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  color: scheme.surfaceContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_outlined, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '写作默认值',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '首页写作台和 AI 出题面板都会从这里的语言与体裁开始。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '默认语言',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: widget.writingDefaults,
                        builder: (context, _) {
                          return SegmentedButton<EssayLanguage>(
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
                            selected: {widget.writingDefaults.language},
                            onSelectionChanged: (selection) {
                              _setDefaultLanguage(selection.first);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '默认体裁',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: widget.writingDefaults,
                        builder: (context, _) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in EssayGenre.values)
                                FilterChip(
                                  label: Text(option.label),
                                  selected:
                                      widget.writingDefaults.genre == option,
                                  onSelected: (_) {
                                    _setDefaultGenre(option);
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  color: scheme.surfaceContainer,
                  child: Row(
                    children: [
                      Icon(Icons.bookmarks_outlined, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('题目预设', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'AI 收藏与手动创建的题目在同一列表中管理',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/presets'),
                        child: const Text('管理'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  color: scheme.surfaceContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.key_outlined, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'DeepSeek 连接',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (widget.apiKeys.hasKey)
                            StatusPill(
                              icon: Icons.check_circle_outline,
                              label: '已保存',
                              background: scheme.primaryContainer,
                              foreground: scheme.onPrimaryContainer,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '密钥只保存在本机的加密存储中，不写入源码、日志或 SQLite。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _keyController,
                        obscureText: _obscureKey,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'DeepSeek API Key',
                          hintText: 'sk-…',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscureKey = !_obscureKey);
                            },
                            tooltip: _obscureKey ? '显示密钥' : '隐藏密钥',
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving || _testing ? null : _saveKey,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? '保存中…' : '保存密钥'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _testing || _saving
                                ? null
                                : _testConnection,
                            icon: const Icon(Icons.wifi_tethering),
                            label: const Text('测试连接'),
                          ),
                          TextButton(
                            onPressed: _saving || _testing
                                ? null
                                : (_keyController.text.isEmpty &&
                                      !widget.apiKeys.hasKey)
                                ? null
                                : _clearKey,
                            child: const Text('移除'),
                          ),
                        ],
                      ),
                      if (_testing) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          '正在连接 DeepSeek，确认密钥是否有效…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_testReply != null) ...[
                        const SizedBox(height: 16),
                        _ConnectionResult(
                          success: true,
                          title: '连接成功',
                          message:
                              '模型回复：$_testReply'
                              '${_latency == null ? '' : ' · ${_latency!.inMilliseconds} ms'}',
                        ),
                      ],
                      if (_testError != null) ...[
                        const SizedBox(height: 16),
                        _ConnectionResult(
                          success: false,
                          title: '连接失败',
                          message: _testError!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  color: scheme.surfaceContainerLow,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('数据与隐私', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              '作文草稿、批改报告和题目预设都保存在设备本地。应用不会在未经操作的情况下上传草稿。',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '文衡 0.4.0 · 中文评分与分享',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionResult extends StatelessWidget {
  const _ConnectionResult({
    required this.success,
    required this.title,
    required this.message,
  });

  final bool success;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = theme.extension<AppSemanticColors>();
    final scheme = theme.colorScheme;
    final background = success
        ? (semantics?.excellentContainer ?? scheme.primaryContainer)
        : (semantics?.criticalContainer ?? scheme.errorContainer);
    final foreground = success
        ? (semantics?.onExcellentContainer ?? scheme.onPrimaryContainer)
        : (semantics?.onCriticalContainer ?? scheme.onErrorContainer);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
