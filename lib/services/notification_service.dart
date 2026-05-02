import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'background_service.dart';
import '../screens/in_app_game_screen.dart';
import '../main.dart'; // To access the navigatorKey

class NotificationService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init({bool isBackground = false}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS requires static categories. We register for 4 options and 2 options
    final List<DarwinNotificationCategory> darwinCategories = [
      DarwinNotificationCategory(
        'trivia_category', // 4 options
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain('action_0', 'A', options: {DarwinNotificationActionOption.foreground}),
          DarwinNotificationAction.plain('action_1', 'B', options: {DarwinNotificationActionOption.foreground}),
          DarwinNotificationAction.plain('action_2', 'C', options: {DarwinNotificationActionOption.foreground}),
          DarwinNotificationAction.plain('action_3', 'D', options: {DarwinNotificationActionOption.foreground}),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
      DarwinNotificationCategory(
        'trivia_category_2', // 2 options (True/False)
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain('action_0', 'A', options: {DarwinNotificationActionOption.foreground}),
          DarwinNotificationAction.plain('action_1', 'B', options: {DarwinNotificationActionOption.foreground}),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
    ];

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: !isBackground,
          requestBadgePermission: !isBackground,
          requestSoundPermission: !isBackground,
          notificationCategories: darwinCategories,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  static final List<NotificationResponse> _pendingResponses = [];

  static void processPendingResponses() {
    for (final response in _pendingResponses) {
      _handleNotificationResponse(response);
    }
    _pendingResponses.clear();
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    // If the navigator isn't ready (e.g. cold start), queue it up.
    if (navigatorKey.currentState == null) {
      _pendingResponses.add(response);
      return;
    }

    if (response.actionId == null && response.payload != null) {
      // actionId is null when the user taps the notification body
      handleInAppNavigation(response.payload!);
    } else {
      // Handled as a button action on the main isolate
      BackgroundService.handleNotificationAction(response, isFromBackgroundIsolate: false).then((_) {
        // After registering the answer, navigate the user to the game screen to see the result
        if (response.payload != null) {
          handleInAppNavigation(response.payload!);
        }
      });
    }
  }

  // Parses the payload and navigates to the game screen
  static void handleInAppNavigation(String payload) {
    final parts = payload.split('|');
    if (parts.length >= 3) {
      final int categoryId = int.parse(parts[0]);
      final String difficulty = parts[1];
      final String categoryName = parts[2];

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => InAppGameScreen(
            categoryId: categoryId,
            categoryName: categoryName,
            difficulty: difficulty,
          ),
        ),
      );
    }
  }

  static Future<void> showQuestionNotification({
    required int id,
    required String categoryName,
    required String difficulty,
    required String questionText,
    required List<String> options,
    required String payload,
  }) async {
    // Build the body string with the question and the options
    final labels = ['A', 'B', 'C', 'D'];
    String formattedBody = "$questionText\n\n";
    for (int i = 0; i < options.length; i++) {
      formattedBody += "${labels[i]}) ${options[i]}\n";
    }

    final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      formattedBody,
      htmlFormatBigText: false,
      contentTitle: '$categoryName (${difficulty.toUpperCase()})',
      htmlFormatContentTitle: false,
    );

    List<AndroidNotificationAction> androidActions = [];
    for (int i = 0; i < options.length; i++) {
      androidActions.add(
        AndroidNotificationAction(
          'action_$i',
          labels[i],
          cancelNotification: true,
          showsUserInterface: false,
        ),
      );
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'trivia_channel',
          'Trivia Questions',
          channelDescription: 'Interactive trivia questions',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigTextStyle,
          actions: androidActions,
        );

    final DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: options.length <= 2 ? 'trivia_category_2' : 'trivia_category',
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await notificationsPlugin.show(
      id: id,
      title: '$categoryName (${difficulty.toUpperCase()})',
      body: formattedBody,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  static Future<void> showResultNotification(String title, String body) async {
    const NotificationDetails platformDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'result_channel',
        'Results',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
      ),
    );
    await notificationsPlugin.show(
      id: 999,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  BackgroundService.handleNotificationAction(notificationResponse, isFromBackgroundIsolate: true);
}
