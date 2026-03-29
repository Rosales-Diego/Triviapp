import 'package:flutter/material.dart';
import 'data/preferences_helper.dart';
import 'services/trivia_api_service.dart';

void main() async {
  // Ensure that Flutter bindings are initialized before calling async code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Shared Preferences
  await PreferencesHelper.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriviaApp Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TestApiScreen(),
    );
  }
}

class TestApiScreen extends StatelessWidget {
  const TestApiScreen({super.key});

  // Function to test the API
  void _testApi() async {
    final apiService = TriviaApiService();

    debugPrint('Searching for questions on the internet...');

    try {
      // We request only 2 questions for testing
      final questions = await apiService.fetchQuestions(amount: 2);

      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        debugPrint('--- Question ${i + 1} ---');
        debugPrint('Category: ${q.category}');
        debugPrint('Difficulty: ${q.difficulty}');
        debugPrint('Question: ${q.questionText}');
        debugPrint('Correct Answer: ${q.correctAnswer}');
        debugPrint('Incorrect Answers: ${q.incorrectAnswers.join(', ')}');
        debugPrint('-----------------------');
      }
      debugPrint('Test successful!');
    } catch (e) {
      debugPrint('Error testing the API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trivia API Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _testApi,
          child: const Text('Download Questions (See Console)'),
        ),
      ),
    );
  }
}
