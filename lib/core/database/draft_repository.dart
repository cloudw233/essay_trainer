import 'package:sqflite/sqflite.dart';

import '../../models/essay_draft.dart';

/// Persistence for the user's drafts.
class DraftRepository {
  DraftRepository(this._db);

  final Database _db;

  Future<void> save(EssayDraft draft) async {
    await _db.insert(
      'drafts',
      draft.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EssayDraft?> findById(String id) async {
    final rows = await _db.query(
      'drafts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EssayDraft.fromDbMap(rows.first);
  }

  Future<List<EssayDraft>> recent({int limit = 5}) async {
    final rows = await _db.query(
      'drafts',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(EssayDraft.fromDbMap).toList(growable: false);
  }

  Future<List<EssayDraft>> all() async {
    final rows = await _db.query('drafts', orderBy: 'updated_at DESC');
    return rows.map(EssayDraft.fromDbMap).toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _db.delete('drafts', where: 'id = ?', whereArgs: [id]);
  }
}
