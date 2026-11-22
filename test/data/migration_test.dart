import 'dart:ffi';
import 'dart:io';

import 'package:essay_trainer/core/database/app_database.dart';
import 'package:essay_trainer/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart' as sqlite_open;

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    if (Platform.isLinux) {
      sqlite_open.open.overrideFor(
        sqlite_open.OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('essay_migration_test_');
    dbPath = p.join(tempDir.path, 'legacy.db');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test(
    'migrates a v1 database and keeps old drafts/presets readable',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            final batch = db.batch();
            batch.execute('''
            CREATE TABLE drafts (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              language TEXT NOT NULL,
              genre TEXT NOT NULL,
              content TEXT NOT NULL DEFAULT '',
              word_count INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
            batch.execute('''
            CREATE TABLE presets (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              language TEXT NOT NULL,
              genre TEXT NOT NULL,
              prompt_text TEXT NOT NULL,
              rubric_text TEXT NOT NULL,
              max_score INTEGER NOT NULL
            )
          ''');
            batch.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
            batch.execute('''
            INSERT INTO drafts
              (id, title, language, genre, content, word_count, created_at, updated_at)
            VALUES
              ('old-draft', 'Old Draft', 'english', 'narrative', 'Old body.', 2, 1000, 2000)
          ''');
            batch.execute('''
            INSERT INTO presets
              (id, name, language, genre, prompt_text, rubric_text, max_score)
            VALUES
              ('old-preset', 'Old Preset', 'chinese', 'other', 'Old prompt.', '', 50)
          ''');
            await batch.commit(noResult: true);
          },
        ),
      );
      await legacy.close();

      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
      );

      final draft = await db.drafts.findById('old-draft');
      expect(draft, isNotNull);
      expect(draft!.promptText, isEmpty);
      expect(draft.promptPresetId, isNull);

      final presets = await db.presets.all();
      expect(presets, hasLength(1));
      expect(presets.single.source, PromptSource.manual);
      expect(presets.single.difficulty, PromptDifficulty.standard);
      expect(presets.single.createdAt.millisecondsSinceEpoch, 0);

      await db.close();
    },
  );
}
