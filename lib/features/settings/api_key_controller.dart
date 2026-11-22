import 'package:flutter/foundation.dart';

import '../../services/secure_key_store.dart';

/// App-wide state for the BYOK API key.
///
/// The key never leaves secure storage except while it is in memory for a
/// request. This controller lets the home screen react immediately when the
/// key is saved or removed in settings.
class ApiKeyController extends ChangeNotifier {
  ApiKeyController(this._store);

  final SecureKeyStore _store;

  String? _apiKey;
  bool _isLoading = false;
  Object? _error;

  String? get apiKey => _apiKey;
  bool get hasKey => _apiKey != null && _apiKey!.isNotEmpty;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> load() async {
    _setLoading(true);
    try {
      _apiKey = await _store.read();
      _error = null;
    } catch (error) {
      _error = error;
      _apiKey = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> save(String key) async {
    _setLoading(true);
    try {
      await _store.write(key);
      _apiKey = key.trim();
      _error = null;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> clear() async {
    _setLoading(true);
    try {
      await _store.delete();
      _apiKey = null;
      _error = null;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
