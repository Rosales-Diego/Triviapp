import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'background_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      // This is the callback for when the app is in the FOREGROUND
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handled via background response to keep logic centralized
      },
      // This is the CRITICAL callback for background actions (buttons)
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static Future<void> showQuestionNotification({
    required int id,
    required String title,
    required String body,
    required List<String> options,
    required String
    payload, // We will send category, difficulty, and correct answer here
  }) async {
    // Create action buttons from the shuffled options
    List<AndroidNotificationAction> androidActions = [];
    for (int i = 0; i < options.length; i++) {
      androidActions.add(
        AndroidNotificationAction(
          'action_$i', // ID of the button
          options[i], // Text shown on the button
          cancelNotification: true, // Closes the notification after clicking
          showsUserInterface: false, // DO NOT open the app
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
          actions: androidActions,
        );

    // For iOS/macOS, actions are defined via categories (we'll keep it simple for now)
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  // Simple notification to show the result (Correct/Incorrect)
  static Future<void> showResultNotification(String title, String body) async {
    const NotificationDetails platformDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'result_channel',
        'Results',
        importance: Importance.low,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _notificationsPlugin.show(
      id: 999,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

// THIS MUST BE A TOP-LEVEL FUNCTION
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // This will be handled in background_service.dart to keep the dispatcher clean
  BackgroundService.handleNotificationAction(notificationResponse);
}
