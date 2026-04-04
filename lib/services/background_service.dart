import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';
import '../services/trivia_api_service.dart';
import '../services/notification_service.dart';
import '../data/preferences_helper.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundService {
  @pragma('vm:entry-point')
  static void handleNotificationAction(NotificationResponse response) async {
    if (response.payload == null || response.actionId == null) return;

    final dbHelper = DatabaseHelper.instance;

    // 1. Decode the payload we sent earlier
    // Format: "category_id|difficulty|correct_answer|queue_id|question_text"
    final List<String> parts = response.payload!.split('|');
    final int categoryId = int.parse(parts[0]);
    final String difficulty = parts[1];
    final String correctAnswer = parts[2];
    final int queueId = int.parse(parts[3]);
    final String questionText = parts[4];

    // 2. Identify which button was pressed
    // The actionId is 'action_0', 'action_1', etc.
    // We need to retrieve the original options to know what text was on that button
    final nextQuestion = await dbHelper.getNextQuestionInQueue(
      categoryId,
      difficulty,
    );
    if (nextQuestion == null || nextQuestion['id'] != queueId) return;

    final List<dynamic> options = jsonDecode(nextQuestion['incorrect_answers']);
    options.add(nextQuestion['correct_answer']);
    // Note: The order in the notification buttons matches how we built them in showQuestionNotification

    // For this to work perfectly, we should have the shuffled list or the index.
    // A better way is to pass the selected text directly if the plugin allowed,
    // but since it only gives actionId, we'll use a more direct approach:
    // We will send the options in the payload too.
  }
}

// This function MUST be top-level (outside any class) to run in a background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize tools inside the background isolate (RAM is empty here)
      await PreferencesHelper.init();
      await NotificationService.init();
      final dbHelper = DatabaseHelper.instance;
      final apiService = TriviaApiService();

      // 2. Fetch active schedules
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> activeSchedules = await db.query(
        'category_schedules',
        where: 'is_active = 1',
      );

      if (activeSchedules.isEmpty) return Future.value(true);

      final now = DateTime.now();
      final currentDay = now.weekday; // 1 (Mon) to 7 (Sun)

      // 3. Evaluate each active category schedule
      for (var schedule in activeSchedules) {
        final int categoryId = schedule['category_id'];
        final String difficulty = schedule['difficulty'];
        final int frequency = schedule['frequency_minutes'];

        // Parse the valid days
        final days = (schedule['days_of_week'] as String)
            .split(',')
            .map(int.parse);
        if (!days.contains(currentDay))
          continue; // Skip if today is not an active day

        final startStr = schedule['start_time'] as String;
        final endStr = schedule['end_time'] as String;

        if (_isCurrentTimeInWindow(startStr, endStr)) {
          // 4. Check if enough time has passed according to frequency_minutes
          final prefs = await SharedPreferences.getInstance();
          final lastNotifiedStr = prefs.getString('last_notified_$categoryId');

          if (lastNotifiedStr != null) {
            final lastNotified = DateTime.parse(lastNotifiedStr);
            if (now.difference(lastNotified).inMinutes < frequency) {
              continue; // Skip this category, it's not time yet
            }
          }

          // 5. Time to notify! Get the VERY NEXT question from the SQLite queue
          Map<String, dynamic>? nextQuestion = await dbHelper
              .getNextQuestionInQueue(categoryId, difficulty);

          // If the queue is empty, the background task fetches more from the API silently
          if (nextQuestion == null) {
            int totalQs = await dbHelper.getTotalQuestions(
              categoryId,
              difficulty,
            );
            int answeredCount = await dbHelper.getAnsweredCount(
              categoryId,
              difficulty,
            );
            int remainingQs = totalQs - answeredCount;

            if (remainingQs > 0) {
              String? token = PreferencesHelper.sessionToken;
              if (token == null) {
                token = await apiService.requestSessionToken();
                await PreferencesHelper.setSessionToken(token);
              }

              int amount = remainingQs > 50 ? 50 : remainingQs;
              final newQuestions = await apiService.fetchQuestions(
                amount: amount,
                categoryId: categoryId,
                difficulty: difficulty,
                token: token,
              );

              if (newQuestions.isNotEmpty) {
                await dbHelper.enqueueQuestions(
                  newQuestions,
                  categoryId,
                  difficulty,
                );
                // Try fetching from the queue again
                nextQuestion = await dbHelper.getNextQuestionInQueue(
                  categoryId,
                  difficulty,
                );
              }
            }
          }

          // 6. Show Notification if we found a question
          if (nextQuestion != null) {
            final List<dynamic> incorrects = jsonDecode(
              nextQuestion['incorrect_answers'],
            );
            List<String> allOptions = List<String>.from(incorrects);
            allOptions.add(nextQuestion['correct_answer']);
            allOptions.shuffle();

            // Create a payload that contains everything the background handler needs
            // Separated by a character like "|"
            final String payload =
                "$categoryId|$difficulty|${nextQuestion['correct_answer']}|${nextQuestion['id']}|${nextQuestion['question_text']}|${allOptions.join('///')}";

            await NotificationService.showQuestionNotification(
              id: categoryId,
              title: 'Trivia: ${schedule['difficulty'].toUpperCase()}',
              body: nextQuestion['question_text'],
              options: allOptions,
              payload: payload,
            );

            // Save the exact time we sent this notification to respect the frequency interval
            await prefs.setString(
              'last_notified_$categoryId',
              now.toIso8601String(),
            );
          }
        }
      }

      return Future.value(true);
    } catch (e) {
      // In a real app we might log this to Crashlytics, but for now we catch it to prevent crashes
      print("Background Task Error: $e");
      return Future.value(false);
    }
  });

  @pragma('vm:entry-point')
  void handleNotificationAction(NotificationResponse response) async {
    final parts = response.payload!.split('|');
    final int categoryId = int.parse(parts[0]);
    final String difficulty = parts[1];
    final String correctAnswer = parts[2];
    final int queueId = int.parse(parts[3]);
    final List<String> allOptions = parts[5].split('///');

    // Identify which option was picked
    final int actionIndex = int.parse(response.actionId!.split('_')[1]);
    final String userPick = allOptions[actionIndex];

    final bool isCorrect = userPick == correctAnswer;

    final dbHelper = DatabaseHelper.instance;

    // 1. Log Stats
    await dbHelper.insertPlayStat(
      categoryId: categoryId,
      difficulty: difficulty,
      dayOfWeek: DateTime.now().weekday,
      isCorrect: isCorrect,
    );

    // 2. Remove from Queue
    await dbHelper.removeQuestionFromQueue(queueId);

    // 3. Show Result Notification
    final String resultTitle = isCorrect ? "✅ Correct!" : "❌ Incorrect";
    final String resultBody = isCorrect
        ? "Well done!"
        : "The correct answer was: $correctAnswer";

    await NotificationService.showResultNotification(resultTitle, resultBody);
  }
}

// Helper to check if the current time falls within the start and end hours
bool _isCurrentTimeInWindow(String startStr, String endStr) {
  final now = DateTime.now();
  final startParts = startStr.split(':');
  final endParts = endStr.split(':');

  DateTime start = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(startParts[0]),
    int.parse(startParts[1]),
  );
  DateTime end = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(endParts[0]),
    int.parse(endParts[1]),
  );

  // Handle overnight schedules (e.g., from 22:00 to 06:00 the next day)
  if (end.isBefore(start)) {
    if (now.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    } else if (now.isBefore(end)) {
      start = start.subtract(const Duration(days: 1));
    }
  }

  return now.isAfter(start) && now.isBefore(end);
}
