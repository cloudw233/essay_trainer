import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the DeepSeek API key in the platform keystore.
///
/// The key is never written to source code, SQLite, logs, or shared
/// preferences. It is only read when a request is about to be made.
class SecureKeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'essay_trainer_secure'),
          );

  static const storageKey = 'deepseek_api_key';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    final value = await _storage.read(key: storageKey);
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> write(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('API Key 不能为空');
    }
    await _storage.write(key: storageKey, value: trimmed);
  }

  Future<void> delete() async {
    await _storage.delete(key: storageKey);
  }
}
