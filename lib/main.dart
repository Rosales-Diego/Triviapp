import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'data/preferences_helper.dart';
import 'screens/onboarding_screen.dart';

// Global key to navigate from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PreferencesHelper.init();
  await NotificationService.init();

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Workmanager().initialize(
        BackgroundService.callbackDispatcher,
      );

      await Workmanager().registerPeriodicTask(
        "trivia_periodic_task",
        "fetch_trivia_question",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint("Workmanager initialization failed: $e");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triviapp',
      navigatorKey: navigatorKey,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.processPendingResponses();
          });
          return const OnboardingScreen();
        },
      ),
    );
  }
}
