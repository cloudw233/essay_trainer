import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'essay_trainer_app.dart';
import 'features/prompt_generation/prompt_generation_controller.dart';
import 'features/settings/api_key_controller.dart';
import 'features/settings/writing_defaults_controller.dart';
import 'services/deepseek_service.dart';
import 'services/grading_service.dart';
import 'services/prompt_generation_service.dart';
import 'services/secure_key_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = await AppDatabase.open();
    final themeController = ThemeController(settings: database.settings);
    await themeController.load();

    final apiKeys = ApiKeyController(SecureKeyStore());
    await apiKeys.load();

    final writingDefaults = WritingDefaultsController(
      settings: database.settings,
    );
    await writingDefaults.load();

    final promptGeneration = PromptGenerationController(
      service: PromptGenerationService(),
    );

    runApp(
      EssayTrainerApp(
        database: database,
        themeController: themeController,
        apiKeys: apiKeys,
        deepSeekService: DeepSeekService(),
        gradingService: GradingService(),
        writingDefaults: writingDefaults,
        promptGeneration: promptGeneration,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('启动失败: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(const _BootstrapFailureApp());
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    final scheme = AppTheme.fallbackScheme(Brightness.light);
    return MaterialApp(
      title: '文衡',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(scheme),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '应用未能启动',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '本地数据库初始化失败。请重启应用；如果问题持续存在，请重新安装。',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
