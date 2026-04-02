import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trivia_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final oldPath = join(dbPath, 'advanced_trivia_stats.db');
    await deleteDatabase(oldPath);
    // --------------------------------------------

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
        is_active INTEGER NOT NULL DEFAULT 1
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
  }

  // --- CRUD Operations for Play Statistics ---

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

  Future<Map<String, dynamic>> getCategoryStats(int categoryId) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_answered,
        SUM(is_correct) as total_correct
      FROM play_statistics
      WHERE category_id = ?
    ''',
      [categoryId],
    );

    return result.first;
  }

  // --- CRUD Operations for Metadata ---

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
      INSERT OR REPLACE INTO category_metadata 
      (category_id, name, total_easy, total_medium, total_hard, last_updated, is_unlocked)
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

  Future<List<Map<String, dynamic>>> getUnlockedCategories() async {
    final db = await instance.database;

    return await db.query(
      'category_metadata',
      where: 'is_unlocked = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
  }

  // --- CRUD Operations for Schedules ---

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

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO category_schedules 
      (category_id, difficulty, days_of_week, start_time, end_time, frequency_minutes, is_active)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        categoryId,
        difficulty,
        daysOfWeek,
        startTime,
        endTime,
        frequencyMinutes,
        isActive ? 1 : 0,
      ],
    );
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

  // --- METHODS FOR IN-APP GAME PROGRESS ---

  Future<int> getTotalQuestions(int categoryId, String difficulty) async {
    final db = await instance.database;
    final result = await db.query(
      'category_metadata',
      columns: ['total_$difficulty'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );

    if (result.isNotEmpty) {
      return result.first['total_$difficulty'] as int;
    }
    return 0;
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
