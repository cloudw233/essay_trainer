import 'package:sqflite/sqflite.dart';

import '../../models/grading_report.dart';

/// Persistence for completed AI reviews.
class ReportRepository {
  ReportRepository(this._db);

  final Database _db;

  Future<void> save(GradingReport report) async {
    await _db.insert(
      'reports',
      report.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GradingReport?> findById(String id) async {
    final rows = await _db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GradingReport.fromDbMap(rows.first);
  }

  Future<List<GradingReport>> all() async {
    final rows = await _db.query('reports', orderBy: 'created_at DESC');
    return rows.map(GradingReport.fromDbMap).toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }
}
