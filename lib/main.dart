import 'package:flutter/material.dart';
import 'data/preferences_helper.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  // Ensure that Flutter bindings are initialized before calling async code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Shared Preferences before the app starts
  await PreferencesHelper.init();

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
