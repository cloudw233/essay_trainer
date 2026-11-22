import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dynamic_color_scope.dart';
import 'core/theme/theme_controller.dart';
import 'features/prompt_generation/prompt_generation_controller.dart';
import 'features/settings/api_key_controller.dart';
import 'features/settings/writing_defaults_controller.dart';
import 'router.dart';
import 'services/deepseek_service.dart';
import 'services/grading_service.dart';

class EssayTrainerApp extends StatefulWidget {
  const EssayTrainerApp({
    super.key,
    required this.database,
    required this.themeController,
    required this.apiKeys,
    required this.deepSeekService,
    required this.gradingService,
    required this.writingDefaults,
    required this.promptGeneration,
  });

  final AppDatabase database;
  final ThemeController themeController;
  final ApiKeyController apiKeys;
  final DeepSeekService deepSeekService;
  final GradingService gradingService;
  final WritingDefaultsController writingDefaults;
  final PromptGenerationController promptGeneration;

  @override
  State<EssayTrainerApp> createState() => _EssayTrainerAppState();
}

class _EssayTrainerAppState extends State<EssayTrainerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      database: widget.database,
      themeController: widget.themeController,
      apiKeys: widget.apiKeys,
      deepSeekService: widget.deepSeekService,
      gradingService: widget.gradingService,
      writingDefaults: widget.writingDefaults,
      promptGeneration: widget.promptGeneration,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightFallback = AppTheme.fallbackScheme(Brightness.light);
    final darkFallback = AppTheme.fallbackScheme(Brightness.dark);

    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        return MaterialApp.router(
          title: '文衡',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(lightFallback),
          darkTheme: AppTheme.themeFor(darkFallback),
          themeMode: widget.themeController.mode,
          routerConfig: _router,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return _DynamicThemeBridge(
              lightFallback: lightFallback,
              darkFallback: darkFallback,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

/// Wraps the navigator in the wallpaper-derived scheme.
///
/// `DynamicColorBuilder` lives in `MaterialApp.builder` as requested. On
/// Android 12+ it supplies the wallpaper palette; on older devices, or before
/// the platform channel replies, the ink-green fallback is used.
class _DynamicThemeBridge extends StatelessWidget {
  const _DynamicThemeBridge({
    required this.lightFallback,
    required this.darkFallback,
    required this.child,
  });

  final ColorScheme lightFallback;
  final ColorScheme darkFallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final scheme = isDark
            ? (darkDynamic ?? darkFallback)
            : (lightDynamic ?? lightFallback);
        final dynamicActive = isDark
            ? darkDynamic != null
            : lightDynamic != null;
        final theme = AppTheme.themeFor(scheme);

        return DynamicColorScope(
          active: dynamicActive,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.systemUiOverlayStyle(scheme),
            child: Theme(data: theme, child: child),
          ),
        );
      },
    );
  }
}
