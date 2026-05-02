import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/trivia_api_service.dart';
import '../data/database_helper.dart';
import '../data/preferences_helper.dart';

class InAppGameScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final String difficulty;

  const InAppGameScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.difficulty,
  });

  @override
  State<InAppGameScreen> createState() => _InAppGameScreenState();
}

class _InAppGameScreenState extends State<InAppGameScreen> {
  final TriviaApiService _apiService = TriviaApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = true;
  String? _errorMessage;

  // State variables for the currently displayed question
  int? _currentQueueId;
  String _currentQuestionText = '';
  String _currentCorrectAnswer = '';

  List<String> _shuffledAnswers = [];
  String? _selectedAnswer;
  bool _isAnswered = false;

  // Global Progress Trackers
  int _totalQuestions = 0;
  int _answeredCount = 0;

  @override
  void initState() {
    super.initState();
    _dbHelper.setCategoryStarted(widget.categoryId, true);
    _loadNextQuestion();
  }

  // 1. Checks the SQLite Queue. If empty, fetches from API.
  Future<void> _loadNextQuestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Refresh global progress stats
      _totalQuestions = await _dbHelper.getTotalQuestions(
        widget.categoryId,
        widget.difficulty,
      );
      if (_totalQuestions == 0) {
        final counts = await _apiService.fetchCategoryQuestionCount(
          widget.categoryId,
        );
        await _dbHelper.upsertCategoryMetadata(
          categoryId: widget.categoryId,
          name: widget.categoryName,
          totalEasy: counts['total_easy_question_count'],
          totalMedium: counts['total_medium_question_count'],
          totalHard: counts['total_hard_question_count'],
          isUnlocked: true,
        );
        _totalQuestions = await _dbHelper.getTotalQuestions(
          widget.categoryId,
          widget.difficulty,
        );
      }

      _answeredCount = await _dbHelper.getAnsweredCount(
        widget.categoryId,
        widget.difficulty,
      );

      // Check if we already finished all possible questions
      if (_totalQuestions > 0 && _answeredCount >= _totalQuestions) {
        _handleTokenEmpty();
        return;
      }

      // Check how many questions are waiting in the SQLite queue
      final queueCount = await _dbHelper.getQueueCount(
        widget.categoryId,
        widget.difficulty,
      );

      // If queue is empty, fetch a new batch from OpenTDB and store it in SQLite
      if (queueCount == 0) {
        await _fetchAndEnqueueBatch();
      }

      // Now pull the first question from the SQLite queue
      final nextQuestionData = await _dbHelper.getNextQuestionInQueue(
        widget.categoryId,
        widget.difficulty,
      );

      if (nextQuestionData == null) {
        // If it's still null, the API might have run out of questions earlier than expected
        _handleTokenEmpty();
        return;
      }

      // 2. Setup the UI state with the fetched question
      _currentQueueId = nextQuestionData['id'];
      _currentQuestionText = nextQuestionData['question_text'];
      _currentCorrectAnswer = nextQuestionData['correct_answer'];

      // Decode the JSON string back to a List of strings
      final List<dynamic> incorrectDecoded = jsonDecode(
        nextQuestionData['incorrect_answers'],
      );

      _shuffledAnswers = List<String>.from(incorrectDecoded);
      _shuffledAnswers.add(_currentCorrectAnswer);
      _shuffledAnswers.shuffle();

      _isAnswered = false;
      _selectedAnswer = null;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (e.toString().contains('TOKEN_EMPTY') ||
          e.toString().contains('API Error Code: 1')) {
        _handleTokenEmpty();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
        }
      }
    }
  }

  // 3. Fetches from API and saves to SQLite Queue
  Future<void> _fetchAndEnqueueBatch() async {
    String? token = PreferencesHelper.sessionToken;
    if (token == null) {
      token = await _apiService.requestSessionToken();
      await PreferencesHelper.setSessionToken(token);
    }

    int remainingQs = _totalQuestions - _answeredCount;
    int amountToRequest = remainingQs > 50 ? 50 : remainingQs;

    final questions = await _apiService.fetchQuestions(
      amount: amountToRequest,
      categoryId: widget.categoryId,
      difficulty: widget.difficulty,
      token: token,
    );

    if (questions.isNotEmpty) {
      await _dbHelper.enqueueQuestions(
        questions,
        widget.categoryId,
        widget.difficulty,
      );
    }
  }

  void _submitAnswer(String answer) async {
    if (_isAnswered || _currentQueueId == null) return;

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
    });

    final bool isCorrect = answer == _currentCorrectAnswer;

    // 1. Save statistics
    await _dbHelper.insertPlayStat(
      categoryId: widget.categoryId,
      difficulty: widget.difficulty,
      dayOfWeek: DateTime.now().weekday,
      isCorrect: isCorrect,
    );

    // 2. Remove the question from the SQLite queue since it's now answered
    await _dbHelper.removeQuestionFromQueue(_currentQueueId!);

    // Wait for visual feedback
    await Future.delayed(const Duration(seconds: 2));

    // Load the next one from the database
    if (mounted) _loadNextQuestion();
  }

  // --- RESTART & END GAME LOGIC ---

  void _restartGame() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Warning: Progress Reset'),
        content: const Text(
          'This will delete your progress for this category and set it to inactive. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final currentToken = PreferencesHelper.sessionToken;
              if (currentToken != null) {
                await _apiService.resetSessionToken(currentToken);
              }

              await _dbHelper.resetCategoryStats(
                widget.categoryId,
                widget.difficulty,
              );

              // NEW: Clear the SQLite queue too!
              await _dbHelper.clearQueue(widget.categoryId, widget.difficulty);
              await _dbHelper.setCategoryStarted(widget.categoryId, false);

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleTokenEmpty() {
    if (mounted) setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: const Text(
          'You have completed all available questions for this category. '
          'Continuing will reset your progress and set the category to inactive.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final currentToken = PreferencesHelper.sessionToken;
              if (currentToken != null) {
                await _apiService.resetSessionToken(currentToken);
              }

              await _dbHelper.resetCategoryStats(
                widget.categoryId,
                widget.difficulty,
              );
              await _dbHelper.clearQueue(widget.categoryId, widget.difficulty);
              await _dbHelper.setCategoryStarted(widget.categoryId, false);

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Color _getButtonColor(String answer) {
    if (!_isAnswered) return Colors.white;
    if (answer == _currentCorrectAnswer) return Colors.green.shade300;
    if (answer == _selectedAnswer && answer != _currentCorrectAnswer) {
      return Colors.red.shade300;
    }
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.categoryName} (${widget.difficulty.toUpperCase()})',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart Progress',
            onPressed: _restartGame,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing question database...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong:\n$_errorMessage',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadNextQuestion,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Since we delete questions upon answering, the global number is just answered + 1
    final int currentGlobalNumber = _answeredCount + 1;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question $currentGlobalNumber of ${_totalQuestions > 0 ? _totalQuestions : 'Unknown'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _totalQuestions > 0
                ? (currentGlobalNumber / _totalQuestions)
                : 0.0,
            backgroundColor: Colors.grey.shade200,
          ),

          const SizedBox(height: 32),

          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _currentQuestionText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          ..._shuffledAnswers.map((answer) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                onPressed: _isAnswered ? null : () => _submitAnswer(answer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getButtonColor(answer),
                  disabledBackgroundColor: _getButtonColor(answer),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  answer,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isAnswered && answer == _currentCorrectAnswer
                        ? Colors.white
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
