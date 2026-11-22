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
  late AppDatabase database;
  final createdAt = DateTime.utc(2026, 2, 3, 4, 5, 6);

  setUpAll(() {
    // The Linux test host ships libsqlite3.so.0 but not the unversioned
    // development symlink that package:sqlite3 asks for by default.
    if (Platform.isLinux) {
      sqlite_open.open.overrideFor(
        sqlite_open.OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('essay_trainer_test_');
    dbPath = p.join(tempDir.path, 'app.db');
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: dbPath,
    );
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  EssayDraft makeDraft({String id = 'draft-1'}) => EssayDraft(
    id: id,
    title: 'A Quiet Morning',
    language: EssayLanguage.english,
    genre: EssayGenre.narrative,
    content: 'The city was still asleep.',
    wordCount: 5,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  GradingReport makeReport({
    String id = 'report-1',
    String draftId = 'draft-1',
  }) => GradingReport(
    id: id,
    draftId: draftId,
    overallScore: 21,
    maxScore: 25,
    dimensionScores: const [
      DimensionScore(name: '语言', score: 8, maxScore: 10, comment: '准确。'),
    ],
    sentenceFeedback: const [
      SentenceFeedback(
        sentenceIndex: 0,
        originalText: 'It was quiet.',
        issueType: FeedbackIssueType.praise,
        severity: FeedbackSeverity.highlight,
        comment: '开篇有画面感。',
        suggestion: 'Keep it.',
      ),
    ],
    paragraphFeedback: const [
      ParagraphFeedback(
        paragraphIndex: 0,
        coherenceComment: '顺畅。',
        contentComment: '具体。',
        suggestion: '继续展开。',
      ),
    ],
    revisedEssay: 'The city was still asleep.',
    rawAiResponse: '{}',
    createdAt: createdAt,
  );

  test('draft writes survive closing and reopening SQLite', () async {
    await database.drafts.save(makeDraft());
    await database.close();

    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: dbPath,
    );

    final restored = await database.drafts.findById('draft-1');

    expect(restored, isNotNull);
    expect(restored!.title, 'A Quiet Morning');
    expect(restored.language, EssayLanguage.english);
    expect(restored.genre, EssayGenre.narrative);
    expect(restored.wordCount, 5);
  });

  test('recent drafts are newest first and respect the limit', () async {
    await database.drafts.save(makeDraft(id: 'old'));
    await database.drafts.save(
      makeDraft(
        id: 'new',
      ).copyWith(updatedAt: createdAt.add(const Duration(days: 1))),
    );

    final recent = await database.drafts.recent(limit: 1);

    expect(recent, hasLength(1));
    expect(recent.single.id, 'new');
  });

  test('reports persist nested feedback and can be listed', () async {
    await database.drafts.save(makeDraft());
    await database.reports.save(makeReport());

    final reports = await database.reports.all();

    expect(reports, hasLength(1));
    expect(reports.single.dimensionScores.single.name, '语言');
    expect(
      reports.single.sentenceFeedback.single.severity,
      FeedbackSeverity.highlight,
    );
  });

  test('deleting a draft cascades to its reports', () async {
    await database.drafts.save(makeDraft());
    await database.reports.save(makeReport());

    await database.drafts.delete('draft-1');

    expect(await database.drafts.findById('draft-1'), isNull);
    expect(await database.reports.all(), isEmpty);
  });

  test('settings round-trip through the key-value table', () async {
    await database.settings.set('theme_mode', 'dark');

    expect(await database.settings.get('theme_mode'), 'dark');
    expect(await database.settings.get('missing'), isNull);
  });
}
