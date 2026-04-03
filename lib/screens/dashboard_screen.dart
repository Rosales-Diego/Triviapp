import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:triviapp/screens/in_app_game_screen.dart';
import '../data/preferences_helper.dart';
import '../data/database_helper.dart';
import 'onboarding_screen.dart';
import 'category_config_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _categoriesFuture = DatabaseHelper.instance.getUnlockedCategories();
    });
  }

  // --- Debug Action ---
  void _resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'trivia_v3.db');
    await deleteDatabase(path);

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
            tooltip: 'Hard Reset App (Debug)',
            onPressed: _resetApp,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading categories:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No categories found. Please reset the app.'),
            );
          }

          final categories = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryName = category['name'];
              final categoryId = category['category_id'];
              // Check if the category is currently active in the database
              final bool isActive = category['is_active'] == 1;

              return Card(
                // Elevate active cards a bit more to make them stand out
                elevation: isActive ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  // Add a subtle green border if active
                  side: BorderSide(
                    color: isActive
                        ? Colors.green.shade300
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 8.0,
                      ),
                      leading: CircleAvatar(
                        // Green background for active, standard for inactive
                        backgroundColor: isActive
                            ? Colors.green.shade100
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.category,
                          color: isActive
                              ? Colors.green.shade700
                              : Colors.deepPurple,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Display a visual "ACTIVE" badge
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: const Text(
                        'Tap gear icon to configure notifications',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) => CategoryConfigScreen(
                                    categoryId: categoryId,
                                    categoryName: categoryName,
                                  ),
                                ),
                              )
                              .then((_) => _loadCategories());
                        },
                      ),
                    ),
                    ButtonBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final schedule = await DatabaseHelper.instance
                                .getCategorySchedule(categoryId);
                            final String savedDifficulty = schedule != null
                                ? schedule['difficulty']
                                : 'medium';

                            if (context.mounted) {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) => InAppGameScreen(
                                        categoryId: categoryId,
                                        categoryName: categoryName,
                                        difficulty: savedDifficulty,
                                      ),
                                    ),
                                  )
                                  .then(
                                    (_) => _loadCategories(),
                                  ); // Refresh in case game was reset
                            }
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
