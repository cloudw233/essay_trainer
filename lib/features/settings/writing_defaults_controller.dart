import 'package:flutter/foundation.dart';

import '../../core/database/settings_repository.dart';
import '../../models/enums.dart';

/// Lightweight app-wide preference for the language/genre selected when the
/// writing desk or AI prompt panel opens.
class WritingDefaultsController extends ChangeNotifier {
  WritingDefaultsController({required SettingsRepository settings})
    : _settings = settings;

  static const languageKey = 'default_language';
  static const genreKey = 'default_genre';

  final SettingsRepository _settings;

  EssayLanguage _language = EssayLanguage.chinese;
  EssayGenre _genre = EssayGenre.narrative;

  EssayLanguage get language => _language;
  EssayGenre get genre => _genre;

  Future<void> load() async {
    final storedLanguage = await _settings.get(languageKey);
    final storedGenre = await _settings.get(genreKey);

    final language = storedLanguage == null
        ? EssayLanguage.chinese
        : essayLanguageFromValue(storedLanguage);
    final genre = storedGenre == null
        ? EssayGenre.narrative
        : essayGenreFromValue(storedGenre);

    if (language == _language && genre == _genre) return;
    _language = language;
    _genre = genre;
    notifyListeners();
  }

  Future<void> setLanguage(EssayLanguage language) async {
    if (language == _language) return;
    final previous = _language;
    _language = language;
    notifyListeners();
    try {
      await _settings.set(languageKey, language.name);
    } catch (_) {
      _language = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setGenre(EssayGenre genre) async {
    if (genre == _genre) return;
    final previous = _genre;
    _genre = genre;
    notifyListeners();
    try {
      await _settings.set(genreKey, genre.name);
    } catch (_) {
      _genre = previous;
      notifyListeners();
      rethrow;
    }
  }
}
