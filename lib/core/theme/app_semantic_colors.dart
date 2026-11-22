import 'package:flutter/material.dart';

/// Semantic colours for grading feedback and score bands.
///
/// Widgets must never hardcode red, amber, or green. Every colour here is
/// derived from a [ColorScheme] role, so the same widget works with a dynamic
/// wallpaper palette, the ink-green fallback, and both brightnesses.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.critical,
    required this.onCritical,
    required this.criticalContainer,
    required this.onCriticalContainer,
    required this.minor,
    required this.onMinor,
    required this.minorContainer,
    required this.onMinorContainer,
    required this.suggestion,
    required this.onSuggestion,
    required this.suggestionContainer,
    required this.onSuggestionContainer,
    required this.highlight,
    required this.onHighlight,
    required this.highlightContainer,
    required this.onHighlightContainer,
    required this.excellent,
    required this.onExcellent,
    required this.excellentContainer,
    required this.onExcellentContainer,
    required this.good,
    required this.onGood,
    required this.goodContainer,
    required this.onGoodContainer,
    required this.needsWork,
    required this.onNeedsWork,
    required this.needsWorkContainer,
    required this.onNeedsWorkContainer,
  });

  /// Feedback that must be fixed.
  final Color critical;
  final Color onCritical;
  final Color criticalContainer;
  final Color onCriticalContainer;

  /// A noticeable but non-blocking issue.
  final Color minor;
  final Color onMinor;
  final Color minorContainer;
  final Color onMinorContainer;

  /// A style or content suggestion.
  final Color suggestion;
  final Color onSuggestion;
  final Color suggestionContainer;
  final Color onSuggestionContainer;

  /// Something worth celebrating or imitating.
  final Color highlight;
  final Color onHighlight;
  final Color highlightContainer;
  final Color onHighlightContainer;

  /// Score band: excellent.
  final Color excellent;
  final Color onExcellent;
  final Color excellentContainer;
  final Color onExcellentContainer;

  /// Score band: good.
  final Color good;
  final Color onGood;
  final Color goodContainer;
  final Color onGoodContainer;

  /// Score band: needs work.
  final Color needsWork;
  final Color onNeedsWork;
  final Color needsWorkContainer;
  final Color onNeedsWorkContainer;

  /// Derives all semantic roles from the current scheme.
  factory AppSemanticColors.fromScheme(ColorScheme scheme) {
    return AppSemanticColors(
      critical: scheme.error,
      onCritical: scheme.onError,
      criticalContainer: scheme.errorContainer,
      onCriticalContainer: scheme.onErrorContainer,
      minor: scheme.tertiary,
      onMinor: scheme.onTertiary,
      minorContainer: scheme.tertiaryContainer,
      onMinorContainer: scheme.onTertiaryContainer,
      suggestion: scheme.secondary,
      onSuggestion: scheme.onSecondary,
      suggestionContainer: scheme.secondaryContainer,
      onSuggestionContainer: scheme.onSecondaryContainer,
      highlight: scheme.primary,
      onHighlight: scheme.onPrimary,
      highlightContainer: scheme.primaryContainer,
      onHighlightContainer: scheme.onPrimaryContainer,
      excellent: scheme.primary,
      onExcellent: scheme.onPrimary,
      excellentContainer: scheme.primaryContainer,
      onExcellentContainer: scheme.onPrimaryContainer,
      good: scheme.tertiary,
      onGood: scheme.onTertiary,
      goodContainer: scheme.tertiaryContainer,
      onGoodContainer: scheme.onTertiaryContainer,
      needsWork: scheme.error,
      onNeedsWork: scheme.onError,
      needsWorkContainer: scheme.errorContainer,
      onNeedsWorkContainer: scheme.onErrorContainer,
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? critical,
    Color? onCritical,
    Color? criticalContainer,
    Color? onCriticalContainer,
    Color? minor,
    Color? onMinor,
    Color? minorContainer,
    Color? onMinorContainer,
    Color? suggestion,
    Color? onSuggestion,
    Color? suggestionContainer,
    Color? onSuggestionContainer,
    Color? highlight,
    Color? onHighlight,
    Color? highlightContainer,
    Color? onHighlightContainer,
    Color? excellent,
    Color? onExcellent,
    Color? excellentContainer,
    Color? onExcellentContainer,
    Color? good,
    Color? onGood,
    Color? goodContainer,
    Color? onGoodContainer,
    Color? needsWork,
    Color? onNeedsWork,
    Color? needsWorkContainer,
    Color? onNeedsWorkContainer,
  }) {
    return AppSemanticColors(
      critical: critical ?? this.critical,
      onCritical: onCritical ?? this.onCritical,
      criticalContainer: criticalContainer ?? this.criticalContainer,
      onCriticalContainer: onCriticalContainer ?? this.onCriticalContainer,
      minor: minor ?? this.minor,
      onMinor: onMinor ?? this.onMinor,
      minorContainer: minorContainer ?? this.minorContainer,
      onMinorContainer: onMinorContainer ?? this.onMinorContainer,
      suggestion: suggestion ?? this.suggestion,
      onSuggestion: onSuggestion ?? this.onSuggestion,
      suggestionContainer: suggestionContainer ?? this.suggestionContainer,
      onSuggestionContainer:
          onSuggestionContainer ?? this.onSuggestionContainer,
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
      highlightContainer: highlightContainer ?? this.highlightContainer,
      onHighlightContainer: onHighlightContainer ?? this.onHighlightContainer,
      excellent: excellent ?? this.excellent,
      onExcellent: onExcellent ?? this.onExcellent,
      excellentContainer: excellentContainer ?? this.excellentContainer,
      onExcellentContainer: onExcellentContainer ?? this.onExcellentContainer,
      good: good ?? this.good,
      onGood: onGood ?? this.onGood,
      goodContainer: goodContainer ?? this.goodContainer,
      onGoodContainer: onGoodContainer ?? this.onGoodContainer,
      needsWork: needsWork ?? this.needsWork,
      onNeedsWork: onNeedsWork ?? this.onNeedsWork,
      needsWorkContainer: needsWorkContainer ?? this.needsWorkContainer,
      onNeedsWorkContainer: onNeedsWorkContainer ?? this.onNeedsWorkContainer,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      critical: Color.lerp(critical, other.critical, t)!,
      onCritical: Color.lerp(onCritical, other.onCritical, t)!,
      criticalContainer: Color.lerp(
        criticalContainer,
        other.criticalContainer,
        t,
      )!,
      onCriticalContainer: Color.lerp(
        onCriticalContainer,
        other.onCriticalContainer,
        t,
      )!,
      minor: Color.lerp(minor, other.minor, t)!,
      onMinor: Color.lerp(onMinor, other.onMinor, t)!,
      minorContainer: Color.lerp(minorContainer, other.minorContainer, t)!,
      onMinorContainer: Color.lerp(
        onMinorContainer,
        other.onMinorContainer,
        t,
      )!,
      suggestion: Color.lerp(suggestion, other.suggestion, t)!,
      onSuggestion: Color.lerp(onSuggestion, other.onSuggestion, t)!,
      suggestionContainer: Color.lerp(
        suggestionContainer,
        other.suggestionContainer,
        t,
      )!,
      onSuggestionContainer: Color.lerp(
        onSuggestionContainer,
        other.onSuggestionContainer,
        t,
      )!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      onHighlight: Color.lerp(onHighlight, other.onHighlight, t)!,
      highlightContainer: Color.lerp(
        highlightContainer,
        other.highlightContainer,
        t,
      )!,
      onHighlightContainer: Color.lerp(
        onHighlightContainer,
        other.onHighlightContainer,
        t,
      )!,
      excellent: Color.lerp(excellent, other.excellent, t)!,
      onExcellent: Color.lerp(onExcellent, other.onExcellent, t)!,
      excellentContainer: Color.lerp(
        excellentContainer,
        other.excellentContainer,
        t,
      )!,
      onExcellentContainer: Color.lerp(
        onExcellentContainer,
        other.onExcellentContainer,
        t,
      )!,
      good: Color.lerp(good, other.good, t)!,
      onGood: Color.lerp(onGood, other.onGood, t)!,
      goodContainer: Color.lerp(goodContainer, other.goodContainer, t)!,
      onGoodContainer: Color.lerp(onGoodContainer, other.onGoodContainer, t)!,
      needsWork: Color.lerp(needsWork, other.needsWork, t)!,
      onNeedsWork: Color.lerp(onNeedsWork, other.onNeedsWork, t)!,
      needsWorkContainer: Color.lerp(
        needsWorkContainer,
        other.needsWorkContainer,
        t,
      )!,
      onNeedsWorkContainer: Color.lerp(
        onNeedsWorkContainer,
        other.onNeedsWorkContainer,
        t,
      )!,
    );
  }
}
