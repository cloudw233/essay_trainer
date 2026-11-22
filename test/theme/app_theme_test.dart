import 'package:essay_trainer/core/theme/app_semantic_colors.dart';
import 'package:essay_trainer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test(
      'fallback light theme uses Material 3, the tonal seed variant and 1.7 line height',
      () {
        final scheme = AppTheme.fallbackScheme(Brightness.light);
        final theme = AppTheme.themeFor(scheme);

        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.brightness, Brightness.light);
        expect(theme.visualDensity, VisualDensity.adaptivePlatformDensity);
        expect(theme.textTheme.bodyLarge?.height, closeTo(1.7, 0.001));
        expect(theme.textTheme.bodyMedium?.height, closeTo(1.7, 0.001));
        expect(
          theme.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<FadeForwardsPageTransitionsBuilder>(),
        );
      },
    );

    test('fallback dark theme keeps the same seed but dark brightness', () {
      final light = AppTheme.fallbackScheme(Brightness.light);
      final dark = AppTheme.fallbackScheme(Brightness.dark);

      expect(dark.brightness, Brightness.dark);
      expect(dark.primary, isNot(light.primary));
      expect(
        AppTheme.themeFor(dark).textTheme.bodyLarge?.height,
        closeTo(1.7, 0.001),
      );
    });

    test(
      'semantic colors are derived from ColorScheme roles, never literals',
      () {
        final scheme = AppTheme.fallbackScheme(Brightness.light);
        final semantics = AppTheme.semanticColorsFor(scheme);

        expect(semantics.critical, scheme.error);
        expect(semantics.criticalContainer, scheme.errorContainer);
        expect(semantics.minor, scheme.tertiary);
        expect(semantics.minorContainer, scheme.tertiaryContainer);
        expect(semantics.suggestion, scheme.secondary);
        expect(semantics.highlight, scheme.primary);
        expect(semantics.highlightContainer, scheme.primaryContainer);
        expect(semantics.excellent, scheme.primary);
        expect(semantics.good, scheme.tertiary);
        expect(semantics.needsWork, scheme.error);
      },
    );

    test('the theme exposes AppSemanticColors as a ThemeExtension', () {
      final theme = AppTheme.themeFor(AppTheme.fallbackScheme(Brightness.dark));

      expect(theme.extension<AppSemanticColors>(), isA<AppSemanticColors>());
    });
  });
}
