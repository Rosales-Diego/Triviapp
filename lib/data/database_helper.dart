import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('advanced_trivia_stats.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // We increment the version from 1 to 2
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // We add the upgrade logic
    );
  }

  // --- Database Migration Logic ---
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // For development, the easiest way to handle schema changes is
      // to drop the old tables and recreate them with the new schema.
      await db.execute('DROP TABLE IF EXISTS category_metadata');
      await db.execute('DROP TABLE IF EXISTS category_schedules');
      await db.execute('DROP TABLE IF EXISTS play_statistics');

      // Recreate tables with the version 2 schema
      await _createDB(db, newVersion);
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const integerType = 'INTEGER NOT NULL';
    const stringType = 'TEXT NOT NULL';

    // 1. Table to store the total available questions per category from the API
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

    // 2. Table to store user's notification schedule preferences per category
    // category_id = 0 means "All Categories"
    await db.execute('''
      CREATE TABLE category_schedules (
        id $idType,
        category_id $integerType,
        days_of_week $stringType, 
        start_time $stringType,
        end_time $stringType,
        frequency_minutes $integerType,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 3. Table to log every answered question for advanced statistics
    // day_of_week: 1 (Monday) to 7 (Sunday)
    // is_correct: 0 (False) or 1 (True)
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

  // Log a single answered question
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

  // Get total answered questions vs correct answers for a specific category
  // Useful for the progress bar and win-rate charts
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

  // Upsert (Insert or Replace) category metadata
  // This handles the scenario where the API adds new questions over time
  Future<void> upsertCategoryMetadata({
    required int categoryId,
    required String name,
    required int totalEasy,
    required int totalMedium,
    required int totalHard,
    required bool isUnlocked, // New parameter
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

  // Get all categories to display on the dashboard
  Future<List<Map<String, dynamic>>> getUnlockedCategories() async {
    final db = await instance.database;

    // We fetch rows where is_unlocked is 1 (true)
    return await db.query(
      'category_metadata',
      where: 'is_unlocked = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
  }

  // Save or update the notification schedule for a category
  Future<void> upsertCategorySchedule({
    required int categoryId,
    required String daysOfWeek,
    required String startTime,
    required String endTime,
    required int frequencyMinutes,
    required bool isActive,
  }) async {
    final db = await instance.database;

    // We check if a schedule already exists for this category to update it or insert a new one
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO category_schedules 
      (category_id, days_of_week, start_time, end_time, frequency_minutes, is_active)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        categoryId,
        daysOfWeek,
        startTime,
        endTime,
        frequencyMinutes,
        isActive ? 1 : 0,
      ],
    );
  }

  // Close connection
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
