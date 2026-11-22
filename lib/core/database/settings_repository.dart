import 'package:sqflite/sqflite.dart';

/// A tiny key-value store for preferences that are not secrets.
///
/// The API key deliberately lives in secure storage instead.
class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String key) async {
    await _db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }
}
