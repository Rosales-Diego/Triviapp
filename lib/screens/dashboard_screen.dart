import 'package:flutter/material.dart';
import '../data/preferences_helper.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // We use the nickname saved in SharedPreferences
        title: Text('Welcome, ${PreferencesHelper.nickname}!'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
