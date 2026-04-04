import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'question_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trivia_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    // Clean up older versions
    await deleteDatabase(join(dbPath, 'trivia_v4.db'));
    await deleteDatabase(join(dbPath, 'trivia_v3.db'));
    await deleteDatabase(join(dbPath, 'advanced_trivia_stats.db'));

    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const integerType = 'INTEGER NOT NULL';
    const stringType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE category_metadata (
        category_id INTEGER PRIMARY KEY,
        name $stringType,
        total_easy $integerType,
        total_medium $integerType,
        total_hard $integerType,
        last_updated $integerType,
        is_unlocked INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE category_schedules (
        id $idType,
        category_id $integerType,
        difficulty $stringType,
        days_of_week $stringType, 
        start_time $stringType,
        end_time $stringType,
        frequency_minutes $integerType,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_started INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE play_statistics (
        id $idType,
        category_id $integerType,
        difficulty $stringType,
        day_of_week $integerType,
        is_correct $integerType,
        timestamp $integerType
      )
    ''');

    // --- NEW TABLE: The shared queue for In-App and Notifications ---
    await db.execute('''
      CREATE TABLE question_queue (
        id $idType,
        category_id $integerType,
        difficulty $stringType,
        question_text $stringType,
        correct_answer $stringType,
        incorrect_answers $stringType
      )
    ''');
  }

  // --- QUESTION QUEUE METHODS ---

  // Adds a batch of questions from the API to the local queue
  Future<void> enqueueQuestions(
    List<Question> questions,
    int categoryId,
    String difficulty,
  ) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var q in questions) {
      batch.insert('question_queue', {
        'category_id': categoryId,
        'difficulty': difficulty,
        'question_text': q.questionText,
        'correct_answer': q.correctAnswer,
        // We store the list of incorrect answers as a JSON string
        'incorrect_answers': jsonEncode(q.incorrectAnswers),
      });
    }

    await batch.commit(noResult: true);
  }

  // Gets the very next question in line for a specific category and difficulty
  Future<Map<String, dynamic>?> getNextQuestionInQueue(
    int categoryId,
    String difficulty,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'question_queue',
      where: 'category_id = ? AND difficulty = ?',
      whereArgs: [categoryId, difficulty],
      orderBy: 'id ASC', // Ensures we always get the oldest (next) question
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  // Removes a question from the queue (called AFTER the user answers it)
  Future<void> removeQuestionFromQueue(int queueId) async {
    final db = await instance.database;
    await db.delete('question_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  // Checks how many questions are currently waiting in the queue
  Future<int> getQueueCount(int categoryId, String difficulty) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM question_queue WHERE category_id = ? AND difficulty = ?',
      [categoryId, difficulty],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Clears the queue for a specific category (used when restarting progress)
  Future<void> clearQueue(int categoryId, String difficulty) async {
    final db = await instance.database;
    await db.delete(
      'question_queue',
      where: 'category_id = ? AND difficulty = ?',
      whereArgs: [categoryId, difficulty],
    );
  }

  // --- EXISTING METHODS (UNCHANGED) ---

  Future<void> setCategoryStarted(int categoryId, bool started) async {
    final db = await instance.database;
    final result = await db.query(
      'category_schedules',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    if (result.isEmpty) {
      await db.insert('category_schedules', {
        'category_id': categoryId,
        'difficulty': 'medium',
        'days_of_week': '1,2,3,4,5',
        'start_time': '9:0',
        'end_time': '21:0',
        'frequency_minutes': 60,
        'is_active': 0,
        'is_started': started ? 1 : 0,
      });
    } else {
      await db.rawUpdate(
        'UPDATE category_schedules SET is_started = ? WHERE category_id = ?',
        [started ? 1 : 0, categoryId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUnlockedCategories() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT m.*, IFNULL(s.is_started, 0) as is_started
      FROM category_metadata m
      LEFT JOIN category_schedules s ON m.category_id = s.category_id
      WHERE m.is_unlocked = 1 ORDER BY m.name ASC
    ''');
  }

  Future<void> upsertCategorySchedule({
    required int categoryId,
    required String difficulty,
    required String daysOfWeek,
    required String startTime,
    required String endTime,
    required int frequencyMinutes,
    required bool isActive,
  }) async {
    final db = await instance.database;
    final data = {
      'category_id': categoryId,
      'difficulty': difficulty,
      'days_of_week': daysOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'frequency_minutes': frequencyMinutes,
      'is_active': isActive ? 1 : 0,
    };
    final count = await db.update(
      'category_schedules',
      data,
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    if (count == 0) {
      data['is_started'] = 0;
      await db.insert('category_schedules', data);
    }
  }

  Future<Map<String, dynamic>?> getCategorySchedule(int categoryId) async {
    final db = await instance.database;
    final result = await db.query(
      'category_schedules',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> upsertCategoryMetadata({
    required int categoryId,
    required String name,
    required int totalEasy,
    required int totalMedium,
    required int totalHard,
    required bool isUnlocked,
  }) async {
    final db = await instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO category_metadata (category_id, name, total_easy, total_medium, total_hard, last_updated, is_unlocked)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        categoryId,
        name,
        totalEasy,
        totalMedium,
        totalHard,
        timestamp,
        isUnlocked ? 1 : 0,
      ],
    );
  }

  Future<void> insertPlayStat({
    required int categoryId,
    required String difficulty,
    required int dayOfWeek,
    required bool isCorrect,
  }) async {
    final db = await instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await db.insert('play_statistics', {
      'category_id': categoryId,
      'difficulty': difficulty,
      'day_of_week': dayOfWeek,
      'is_correct': isCorrect ? 1 : 0,
      'timestamp': timestamp,
    });
  }

  Future<int> getTotalQuestions(int categoryId, String difficulty) async {
    final db = await instance.database;
    final result = await db.query(
      'category_metadata',
      columns: ['total_$difficulty'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return result.isNotEmpty ? result.first['total_$difficulty'] as int : 0;
  }

  Future<int> getAnsweredCount(int categoryId, String difficulty) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM play_statistics WHERE category_id = ? AND difficulty = ?',
      [categoryId, difficulty],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> resetCategoryStats(int categoryId, String difficulty) async {
    final db = await instance.database;
    await db.delete(
      'play_statistics',
      where: 'category_id = ? AND difficulty = ?',
      whereArgs: [categoryId, difficulty],
    );
  }

  Future<void> setCategoryInactive(int categoryId) async {
    final db = await instance.database;
    await db.rawUpdate(
      'UPDATE category_schedules SET is_active = 0, is_started = 0 WHERE category_id = ?',
      [categoryId],
    );
  }

  Future<void> destroyDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, 'trivia_v5.db'));
    await deleteDatabase(join(dbPath, 'trivia_v4.db'));
    await deleteDatabase(join(dbPath, 'trivia_v3.db'));
    await deleteDatabase(join(dbPath, 'advanced_trivia_stats.db'));
  }
}
