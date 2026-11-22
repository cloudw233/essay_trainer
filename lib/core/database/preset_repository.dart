import 'package:sqflite/sqflite.dart';

import '../../models/prompt_preset.dart';

/// Persistence for reusable prompts and rubrics.
class PresetRepository {
  PresetRepository(this._db);

  final Database _db;

  Future<void> save(PromptPreset preset) async {
    await _db.insert(
      'presets',
      preset.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PromptPreset>> all() async {
    final rows = await _db.query('presets', orderBy: 'name ASC');
    return rows.map(PromptPreset.fromDbMap).toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _db.delete('presets', where: 'id = ?', whereArgs: [id]);
  }
}
