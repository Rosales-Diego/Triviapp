import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/database_helper.dart';
import '../services/trivia_api_service.dart';
import '../services/notification_service.dart';
import '../data/preferences_helper.dart';

class BackgroundService {
  static Future<void> handleNotificationAction(
    NotificationResponse response, {
    bool isFromBackgroundIsolate = false,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (isFromBackgroundIsolate) {
        await NotificationService.init(isBackground: true);
      }

      if (response.id != null) {
        await NotificationService.notificationsPlugin.cancel(id: response.id!);
      }

      // Ignore if it was a body tap (handled in NotificationService)
      if (response.payload == null || response.actionId == null) return;

      final dbHelper = DatabaseHelper.instance;
      final parts = response.payload!.split('|');

      // Payload mapping:
      // 0: categoryId, 1: difficulty, 2: categoryName, 3: correctAnswer, 4: queueId, 5: options
      final int categoryId = int.parse(parts[0]);
      final String difficulty = parts[1];
      final String correctAnswer = parts[3];
      final int queueId = int.parse(parts[4]);
      final List<String> allOptions = parts[5].split('///');

      final int actionIndex = int.parse(response.actionId!.split('_')[1]);
      final String userPick = allOptions[actionIndex];

      final bool isCorrect = userPick == correctAnswer;

      await dbHelper.insertPlayStat(
        categoryId: categoryId,
        difficulty: difficulty,
        dayOfWeek: DateTime.now().weekday,
        isCorrect: isCorrect,
      );

      await dbHelper.removeQuestionFromQueue(queueId);

      final String resultTitle = isCorrect ? "✅ Correct!" : "❌ Incorrect";
      final String resultBody = isCorrect
          ? "Great job!"
          : "The correct answer was: $correctAnswer";

      await NotificationService.showResultNotification(resultTitle, resultBody);
    } catch (e) {
      await NotificationService.showResultNotification(
        "Bg Task Error",
        e.toString(),
      );
    }
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await runScheduledTasks();
        return Future.value(true);
      } catch (e) {
        debugPrint("Background Task Error: $e");
        return Future.value(false);
      }
    });
  }

  static Future<String> runScheduledTasks({bool isForced = false}) async {
    await PreferencesHelper.init();
    if (!isForced) {
      await NotificationService.init(isBackground: true);
    }
    final dbHelper = DatabaseHelper.instance;
    final apiService = TriviaApiService();

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> activeSchedules = await db.query(
      'category_schedules',
      where: 'is_active = 1',
    );

    if (activeSchedules.isEmpty) return "No active schedules configured!";

    final now = DateTime.now();
    final currentDay = now.weekday;
    int sentCount = 0;

    for (var schedule in activeSchedules) {
      final int categoryId = schedule['category_id'];
      final String difficulty = schedule['difficulty'];

      final days = (schedule['days_of_week'] as String)
          .split(',')
          .map(int.parse);
      if (!isForced && !days.contains(currentDay)) continue;

      if (isForced ||
          _isCurrentTimeInWindow(
            schedule['start_time'],
            schedule['end_time'],
          )) {
        // Check frequency limit
        final int frequencyMinutes = schedule['frequency_minutes'];
        final int lastTimeMillis = PreferencesHelper.getLastNotificationTime(
          categoryId,
        );
        final int elapsedMinutes = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastTimeMillis))
            .inMinutes;

        if (!isForced && elapsedMinutes < frequencyMinutes) {
          continue;
        }

        Map<String, dynamic>? nextQuestion = await dbHelper
            .getNextQuestionInQueue(categoryId, difficulty);

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
            final newQs = await apiService.fetchQuestions(
              amount: amount,
              categoryId: categoryId,
              difficulty: difficulty,
              token: token,
            );
            if (newQs.isNotEmpty) {
              await dbHelper.enqueueQuestions(newQs, categoryId, difficulty);
              nextQuestion = await dbHelper.getNextQuestionInQueue(
                categoryId,
                difficulty,
              );
            }
          }
        }

        if (nextQuestion != null) {
          final catResult = await db.query(
            'category_metadata',
            where: 'category_id = ?',
            whereArgs: [categoryId],
          );
          final String categoryName = catResult.isNotEmpty
              ? catResult.first['name'].toString()
              : 'Trivia';

          final List<dynamic> incorrects = jsonDecode(
            nextQuestion['incorrect_answers'],
          );
          List<String> allOptions = [];

          // Platform check: 4 options for iOS, up to 3 for Android
          if (Platform.isIOS || Platform.isMacOS) {
            allOptions = List<String>.from(incorrects);
          } else {
            // Keep up to 2 incorrect answers
            allOptions = List<String>.from(incorrects.take(2));
          }
          allOptions.add(nextQuestion['correct_answer']);

          allOptions.shuffle();

          // Add categoryName to payload (Index 2)
          final String payload =
              "$categoryId|$difficulty|$categoryName|${nextQuestion['correct_answer']}|${nextQuestion['id']}|${allOptions.join('///')}";

          final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          await NotificationService.showQuestionNotification(
            id: notificationId,
            categoryName: categoryName,
            difficulty: difficulty,
            questionText: nextQuestion['question_text'],
            options: allOptions,
            payload: payload,
          );

          // Update last notification time so frequency is respected
          await PreferencesHelper.setLastNotificationTime(
            categoryId,
            DateTime.now().millisecondsSinceEpoch,
          );
          sentCount++;
        }
      }
    }

    if (sentCount == 0) return "No questions available to send.";
    return "Sent $sentCount notifications!";
  }

  static bool _isCurrentTimeInWindow(String startStr, String endStr) {
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
    if (end.isBefore(start)) {
      if (now.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      } else if (now.isBefore(end)) {
        start = start.subtract(const Duration(days: 1));
      }
    }
    return now.isAfter(start) && now.isBefore(end);
  }
}
