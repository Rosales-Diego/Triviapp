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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const integerType = 'INTEGER NOT NULL';
    const stringType = 'TEXT NOT NULL';

    // 1. Table to store the total available questions per category from the API
    await db.execute('''
      CREATE TABLE category_metadata (
        category_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        total_easy INTEGER NOT NULL,
        total_medium INTEGER NOT NULL,
        total_hard INTEGER NOT NULL,
        last_updated INTEGER NOT NULL
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
  }) async {
    final db = await instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO category_metadata 
      (category_id, name, total_easy, total_medium, total_hard, last_updated)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [categoryId, name, totalEasy, totalMedium, totalHard, timestamp],
    );
  }

  // Get all categories to display on the dashboard
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;

    // We fetch all rows from category_metadata, ordered alphabetically by name
    return await db.query('category_metadata', orderBy: 'name ASC');
  }

  // Close connection
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
