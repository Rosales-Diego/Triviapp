import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/preferences_helper.dart';
import '../data/database_helper.dart';
import 'onboarding_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Future variable to hold our categories
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future when the screen loads
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _categoriesFuture = DatabaseHelper.instance.getAllCategories();
    });
  }

  // --- Debug Action ---
  void _resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears all saved data

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${PreferencesHelper.nickname}!'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset App (Debug)',
            onPressed: _resetApp,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading categories:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 3. Empty State (should not happen if Onboarding worked, but good practice)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No categories found. Please reset the app.'),
            );
          }

          // 4. Success State: Build the list
          final categories = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryName = category['name'];
              final categoryId = category['category_id'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: const Icon(Icons.category, color: Colors.deepPurple),
                  ),
                  title: Text(
                    categoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Tap to configure schedule & difficulty',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to Category Configuration Screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Selected: $categoryName (ID: $categoryId)',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
