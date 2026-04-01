import 'package:flutter/material.dart';
import '../data/preferences_helper.dart';
import '../services/trivia_api_service.dart';
import '../data/database_helper.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  // State variable to show a loading spinner while downloading categories
  bool _isLoading = false;

  void _saveAndContinue() async {
    // 1. Update UI to show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Save nickname
      final nickname = _nicknameController.text.trim();
      await PreferencesHelper.setNickname(
        nickname.isNotEmpty ? nickname : 'Anonymous',
      );

      // 3. Fetch base categories from API (Just 1 API call, no rate limit issue)
      final apiService = TriviaApiService();
      final categories = await apiService.fetchCategories();

      // 4. Save categories to SQLite Database
      final dbHelper = DatabaseHelper.instance;
      for (var cat in categories) {
        // We set totals to 0 for now. We will fetch exact counts later
        // when the user actually selects a category to configure.
        await dbHelper.upsertCategoryMetadata(
          categoryId: cat['id'],
          name: cat['name'],
          totalEasy: 0,
          totalMedium: 0,
          totalHard: 0,
        );
      }

      // 5. Mark onboarding as complete
      await PreferencesHelper.setFirstTimeCompleted();

      // 6. Navigate to Dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      // If there is no internet or the API fails, stop loading and show an error
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to the trivia server: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 100,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to TriviApp!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter a nickname and we will download the latest categories.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nicknameController,
                // Disable input if it is currently loading
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              // Show a loading spinner or the button based on _isLoading state
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Start Learning',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
