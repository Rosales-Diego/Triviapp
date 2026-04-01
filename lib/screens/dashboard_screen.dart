import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/preferences_helper.dart';
import 'onboarding_screen.dart'; // Add this import

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${PreferencesHelper.nickname}!'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // DEBUG BUTTON: Resets the app to test Onboarding again
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset App (Debug)',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Clears all saved data

              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const OnboardingScreen(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Main Dashboard (Coming Soon)\nHere we will list the categories.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
