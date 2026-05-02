import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:triviapp/data/database_helper.dart';
import 'package:triviapp/data/question_model.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for testing SQLite on Desktop/Dart VM
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Tests', () {
    setUp(() async {
      // Clear out the database before each test to ensure a clean slate
      await DatabaseHelper.instance.destroyDatabase();
    });

    tearDownAll(() async {
      await DatabaseHelper.instance.destroyDatabase();
    });

    test('upsertCategoryMetadata should insert and retrieve category correctly', () async {
      await DatabaseHelper.instance.upsertCategoryMetadata(
        categoryId: 9,
        name: 'General Knowledge',
        totalEasy: 10,
        totalMedium: 20,
        totalHard: 30,
        isUnlocked: true,
      );

      final categories = await DatabaseHelper.instance.getUnlockedCategories();
      expect(categories.length, 1);
      expect(categories.first['name'], 'General Knowledge');
      expect(categories.first['total_easy'], 10);
      expect(categories.first['is_unlocked'], 1);
    });

    test('upsertCategorySchedule should create and update schedules', () async {
      await DatabaseHelper.instance.upsertCategorySchedule(
        categoryId: 9,
        difficulty: 'easy',
        daysOfWeek: '1,2,3',
        startTime: '09:00',
        endTime: '17:00',
        frequencyMinutes: 60,
        isActive: true,
      );

      var schedule = await DatabaseHelper.instance.getCategorySchedule(9);
      expect(schedule, isNotNull);
      expect(schedule!['difficulty'], 'easy');
      expect(schedule['is_active'], 1);

      // Now update
      await DatabaseHelper.instance.upsertCategorySchedule(
        categoryId: 9,
        difficulty: 'medium',
        daysOfWeek: '1,2',
        startTime: '10:00',
        endTime: '12:00',
        frequencyMinutes: 30,
        isActive: false,
      );

      schedule = await DatabaseHelper.instance.getCategorySchedule(9);
      expect(schedule!['difficulty'], 'medium');
      expect(schedule['is_active'], 0);
    });

    test('Queue operations: enqueue, get, remove, count, clear', () async {
      final mockQuestion1 = Question(
        category: 'General Knowledge',
        difficulty: 'easy',
        questionText: 'Test question 1?',
        correctAnswer: 'Yes',
        incorrectAnswers: ['No'],
      );

      final mockQuestion2 = Question(
        category: 'General Knowledge',
        difficulty: 'easy',
        questionText: 'Test question 2?',
        correctAnswer: 'True',
        incorrectAnswers: ['False'],
      );

      // Enqueue
      await DatabaseHelper.instance.enqueueQuestions([mockQuestion1, mockQuestion2], 9, 'easy');

      // Count
      var count = await DatabaseHelper.instance.getQueueCount(9, 'easy');
      expect(count, 2);

      // Get next
      var nextQuestion = await DatabaseHelper.instance.getNextQuestionInQueue(9, 'easy');
      expect(nextQuestion, isNotNull);
      expect(nextQuestion!['question_text'], 'Test question 1?');

      // Remove
      await DatabaseHelper.instance.removeQuestionFromQueue(nextQuestion['id']);
      count = await DatabaseHelper.instance.getQueueCount(9, 'easy');
      expect(count, 1);

      // Clear
      await DatabaseHelper.instance.clearQueue(9, 'easy');
      count = await DatabaseHelper.instance.getQueueCount(9, 'easy');
      expect(count, 0);
    });

    test('Statistics operations: insert, get count, reset', () async {
      await DatabaseHelper.instance.insertPlayStat(
        categoryId: 9,
        difficulty: 'hard',
        dayOfWeek: 1,
        isCorrect: true,
      );
      await DatabaseHelper.instance.insertPlayStat(
        categoryId: 9,
        difficulty: 'hard',
        dayOfWeek: 2,
        isCorrect: false,
      );

      var count = await DatabaseHelper.instance.getAnsweredCount(9, 'hard');
      expect(count, 2);

      await DatabaseHelper.instance.resetCategoryStats(9, 'hard');
      
      count = await DatabaseHelper.instance.getAnsweredCount(9, 'hard');
      expect(count, 0);
    });
  });
}
