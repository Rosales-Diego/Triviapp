import 'package:workmanager/workmanager.dart';
import '../data/database_helper.dart';
import '../services/trivia_api_service.dart';
import '../services/notification_service.dart';
import 'dart:math';

// This function is executed in a dedicated background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final apiService = TriviaApiService();

      // 1. Fetch all active schedules from the database
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> activeSchedules = await db.query(
        'category_schedules',
        where: 'is_active = 1',
      );

      if (activeSchedules.isEmpty) return Future.value(true);

      // 2. Filter schedules by current time and day
      final now = DateTime.now();
      final currentDay = now.weekday; // 1 (Mon) to 7 (Sun)

      for (var schedule in activeSchedules) {
        final days = (schedule['days_of_week'] as String)
            .split(',')
            .map(int.parse);

        if (days.contains(currentDay)) {
          // Check if current time is within start_time and end_time range
          final startStr = schedule['start_time'] as String;
          final endStr = schedule['end_time'] as String;

          if (_isCurrentTimeInWindow(startStr, endStr)) {
            // 3. Fetch a single question for this category
            final questions = await apiService.fetchQuestions(
              amount: 1,
              categoryId: schedule['category_id'],
              difficulty: schedule['difficulty'],
            );

            if (questions.isNotEmpty) {
              final question = questions.first;

              // 4. Trigger the notification
              await NotificationService.showNotification(
                id: schedule['category_id'],
                title: 'Trivia Time: ${schedule['difficulty'].toUpperCase()}',
                body: question.questionText,
              );
            }
          }
        }
      }

      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

// Helper to check if now is between saved HH:mm strings
bool _isCurrentTimeInWindow(String startStr, String endStr) {
  final now = DateTime.now();
  final startParts = startStr.split(':');
  final endParts = endStr.split(':');

  final start = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(startParts[0]),
    int.parse(startParts[1]),
  );
  final end = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(endParts[0]),
    int.parse(endParts[1]),
  );

  return now.isAfter(start) && now.isBefore(end);
}
