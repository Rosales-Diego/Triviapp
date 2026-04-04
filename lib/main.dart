import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'data/preferences_helper.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PreferencesHelper.init();
  await NotificationService.init();

  // Solo iniciamos Workmanager si estamos en un teléfono
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

      await Workmanager().registerPeriodicTask(
        "trivia_periodic_task",
        "fetch_trivia_question",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
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
    // Check if it's the user's first time opening the app
    final bool isFirstTime = PreferencesHelper.isFirstTime;

    return MaterialApp(
      title: 'TriviaApp',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Automatically route to Onboarding or Dashboard based on the flag
      home: isFirstTime ? const OnboardingScreen() : const DashboardScreen(),
    );
  }
}
