import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Incrementing version to 4 to add the 'is_started' column
    _database = await _initDB('trivia_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    // Cleaning up old versions
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
        is_started INTEGER NOT NULL DEFAULT 0 -- NEW COLUMN
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

  // Marks a category as started. If no configuration exists yet, it creates a default one.
  Future<void> setCategoryStarted(int categoryId, bool started) async {
    final db = await instance.database;

    // 1. Check if a configuration row already exists for this category
    final result = await db.query(
      'category_schedules',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );

    if (result.isEmpty) {
      // 2. If it does NOT exist, insert a default row with the started status
      await db.insert('category_schedules', {
        'category_id': categoryId,
        'difficulty': 'medium', // Default difficulty
        'days_of_week': '1,2,3,4,5',
        'start_time': '9:0',
        'end_time': '21:0',
        'frequency_minutes': 60,
        'is_active': 0, // Notifications OFF by default
        'is_started': started ? 1 : 0,
      });
    } else {
      // 3. If it DOES exist, simply update the is_started column
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
      WHERE m.is_unlocked = 1
      ORDER BY m.name ASC
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
      data['is_started'] = 0; // Default for new records
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
