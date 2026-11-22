import 'package:go_router/go_router.dart';

import 'core/database/app_database.dart';
import 'core/theme/theme_controller.dart';
import 'features/editor/editor_page.dart';
import 'features/grading/grading_page.dart';
import 'features/history/history_page.dart';
import 'features/report/report_page.dart';
import 'features/home/home_page.dart';
import 'features/presets/preset_library_page.dart';
import 'features/prompt_generation/prompt_generation_controller.dart';
import 'features/settings/api_key_controller.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/writing_defaults_controller.dart';
import 'features/shell/app_shell.dart';
import 'models/enums.dart';
import 'services/deepseek_service.dart';
import 'services/grading_service.dart';

/// Builds the app's navigation graph.
///
/// The three top-level destinations live in a stateful shell so each keeps its
/// own scroll position. Writing and reports are pushed above the shell.
GoRouter buildRouter({
  required AppDatabase database,
  required ThemeController themeController,
  required ApiKeyController apiKeys,
  required DeepSeekService deepSeekService,
  required GradingService gradingService,
  required WritingDefaultsController writingDefaults,
  required PromptGenerationController promptGeneration,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) {
                  return HomePage(
                    drafts: database.drafts,
                    presets: database.presets,
                    apiKeys: apiKeys,
                    writingDefaults: writingDefaults,
                    promptGeneration: promptGeneration,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => HistoryPage(
                  reports: database.reports,
                  drafts: database.drafts,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) {
                  return SettingsPage(
                    themeController: themeController,
                    apiKeys: apiKeys,
                    deepSeekService: deepSeekService,
                    writingDefaults: writingDefaults,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/presets',
        builder: (context, state) {
          return PresetLibraryPage(presets: database.presets);
        },
      ),
      GoRoute(
        path: '/grading',
        builder: (context, state) {
          final draftId = state.uri.queryParameters['draftId'] ?? '';
          return GradingPage(
            draftId: draftId,
            drafts: database.drafts,
            reports: database.reports,
            apiKeys: apiKeys,
            gradingService: gradingService,
          );
        },
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          final reportId = state.uri.queryParameters['reportId'] ?? '';
          return ReportPage(
            reportId: reportId,
            reports: database.reports,
            drafts: database.drafts,
          );
        },
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return EditorPage(
            drafts: database.drafts,
            apiKeys: apiKeys,
            draftId: query['draftId'],
            initialLanguage: essayLanguageFromValue(query['language']),
            initialGenre: essayGenreFromValue(query['genre']),
          );
        },
      ),
    ],
  );
}
