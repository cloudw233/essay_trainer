import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'draft_repository.dart';
import 'preset_repository.dart';
import 'report_repository.dart';
import 'settings_repository.dart';

/// The local SQLite store for drafts, reports, presets, and preferences.
///
/// All data stays on the device. Since there is no server, this is the source
/// of truth for the history and the writing workspace.
class AppDatabase {
  AppDatabase._(this._db)
    : drafts = DraftRepository(_db),
      reports = ReportRepository(_db),
      presets = PresetRepository(_db),
      settings = SettingsRepository(_db);

  static const _databaseName = 'essay_trainer.db';
  static const _schemaVersion = 3;

  final Database _db;

  final DraftRepository drafts;
  final ReportRepository reports;
  final PresetRepository presets;
  final SettingsRepository settings;

  /// Opens the database. [factory] and [path] are injectable so tests can use
  /// `sqflite_common_ffi` and a temporary file.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final resolvedFactory = factory ?? databaseFactory;
    final resolvedPath =
        path ?? p.join(await resolvedFactory.getDatabasesPath(), _databaseName);

    final database = await resolvedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _migrateToVersion2(db);
          }
          if (oldVersion < 3) {
            await _migrateToVersion3(db);
          }
        },
      ),
    );

    return AppDatabase._(database);
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE drafts (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        language TEXT NOT NULL,
        genre TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        word_count INTEGER NOT NULL DEFAULT 0,
        prompt_text TEXT NOT NULL DEFAULT '',
        prompt_preset_id TEXT,
        required_words INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_drafts_updated_at ON drafts(updated_at DESC)',
    );

    batch.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        draft_id TEXT NOT NULL,
        overall_score REAL NOT NULL,
        max_score REAL NOT NULL,
        dimension_scores TEXT NOT NULL,
        sentence_feedback TEXT NOT NULL,
        paragraph_feedback TEXT NOT NULL,
        revised_essay TEXT NOT NULL,
        raw_ai_response TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (draft_id) REFERENCES drafts(id) ON DELETE CASCADE
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_reports_created_at ON reports(created_at DESC)',
    );

    batch.execute('''
      CREATE TABLE presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        language TEXT NOT NULL,
        genre TEXT NOT NULL,
        prompt_text TEXT NOT NULL,
        rubric_text TEXT NOT NULL,
        max_score INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        difficulty TEXT NOT NULL DEFAULT 'standard',
        suggested_word_count INTEGER NOT NULL DEFAULT 0,
        rationale TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// Adds the prompt binding and AI prompt metadata while keeping existing
  /// drafts/presets usable. Existing rows become manual presets, and old drafts
  /// get an empty prompt snapshot.
  static Future<void> _migrateToVersion2(Database db) async {
    final batch = db.batch();
    batch.execute(
      "ALTER TABLE drafts ADD COLUMN prompt_text TEXT NOT NULL DEFAULT ''",
    );
    batch.execute('ALTER TABLE drafts ADD COLUMN prompt_preset_id TEXT');
    batch.execute(
      "ALTER TABLE presets ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
    );
    batch.execute(
      "ALTER TABLE presets ADD COLUMN difficulty TEXT NOT NULL DEFAULT 'standard'",
    );
    batch.execute(
      'ALTER TABLE presets ADD COLUMN suggested_word_count INTEGER NOT NULL DEFAULT 0',
    );
    batch.execute(
      "ALTER TABLE presets ADD COLUMN rationale TEXT NOT NULL DEFAULT ''",
    );
    batch.execute(
      'ALTER TABLE presets ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
    );
    await batch.commit(noResult: true);
  }

  /// Stores the word target a topic asks for. Drafts written before this
  /// column existed keep 0, which the editor reads as "use the language
  /// default".
  static Future<void> _migrateToVersion3(Database db) async {
    await db.execute(
      'ALTER TABLE drafts ADD COLUMN required_words INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> close() => _db.close();
}
