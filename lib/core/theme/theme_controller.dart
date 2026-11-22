import 'package:flutter/material.dart';

import '../database/settings_repository.dart';

/// Owns the user's light/dark preference and persists it locally.
///
/// The default is [ThemeMode.system]; the settings screen can override it with
/// a three-way segmented control.
class ThemeController extends ChangeNotifier {
  ThemeController({
    required SettingsRepository settings,
    ThemeMode initialMode = ThemeMode.system,
  }) : _settings = settings,
       _mode = initialMode;

  static const storageKey = 'theme_mode';

  final SettingsRepository _settings;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final stored = await _settings.get(storageKey);
    if (stored == null) return;

    final loaded = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
    if (loaded == _mode) return;
    _mode = loaded;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;

    final previous = _mode;
    _mode = mode;
    notifyListeners();

    try {
      await _settings.set(storageKey, mode.name);
    } catch (_) {
      _mode = previous;
      notifyListeners();
      rethrow;
    }
  }
}

extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
}
