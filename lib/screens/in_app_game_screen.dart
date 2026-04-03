import 'package:flutter/material.dart';
import '../services/trivia_api_service.dart';
import '../data/database_helper.dart';
import '../data/preferences_helper.dart';
import '../data/question_model.dart';

// --- SESSION CACHE MANAGER ---
// This holds the exact state of the game in memory so if the user
// leaves the screen and comes back, they resume exactly where they left off.
class _GameCacheData {
  List<Question> questions = [];
  int currentIndex = 0;
  int globalOffset = 0;
  int totalQuestions = 0;
  List<String> shuffledAnswers = [];
  String? selectedAnswer;
  bool isAnswered = false;
}

class _GameSessionManager {
  static final Map<String, _GameCacheData> activeSessions = {};

  static String getKey(int id, String diff) => '${id}_$diff';
  static void clear(int id, String diff) =>
      activeSessions.remove(getKey(id, diff));
}

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

  late String _sessionKey;
  _GameCacheData? _sessionData;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sessionKey = _GameSessionManager.getKey(
      widget.categoryId,
      widget.difficulty,
    );

    // Mark as started as soon as the user enters the screen
    _dbHelper.setCategoryStarted(widget.categoryId, true);

    if (_GameSessionManager.activeSessions.containsKey(_sessionKey)) {
      _sessionData = _GameSessionManager.activeSessions[_sessionKey];
      _isLoading = false;
    } else {
      _startGame();
    }
  }

  Future<void> _startGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Manage the Session Token
      String? token = PreferencesHelper.sessionToken;
      if (token == null) {
        token = await _apiService.requestSessionToken();
        await PreferencesHelper.setSessionToken(token);
      }

      // 2. Fetch global progress from local DB
      int totalQs = await _dbHelper.getTotalQuestions(
        widget.categoryId,
        widget.difficulty,
      );

      // 3. Sync metadata on-the-fly if it's missing (e.g. user skipped config screen)
      if (totalQs == 0) {
        final counts = await _apiService.fetchCategoryQuestionCount(
          widget.categoryId,
        );
        await _dbHelper.upsertCategoryMetadata(
          categoryId: widget.categoryId,
          name: widget.categoryName,
          totalEasy: counts['total_easy_question_count'],
          totalMedium: counts['total_medium_question_count'],
          totalHard: counts['total_hard_question_count'],
          isUnlocked: true, // If they are playing it, it's already unlocked
        );
        // Read the updated total
        totalQs = await _dbHelper.getTotalQuestions(
          widget.categoryId,
          widget.difficulty,
        );
      }

      final answeredCount = await _dbHelper.getAnsweredCount(
        widget.categoryId,
        widget.difficulty,
      );

      // 4. SMART FETCHING: Calculate exactly how many questions to ask for
      int remainingQs = totalQs - answeredCount;

      if (remainingQs <= 0) {
        // The user has genuinely answered everything in this category/difficulty
        _handleTokenEmpty();
        return;
      }

      // Max request is 50. If remaining is less than 50, we only ask for the remaining.
      int amountToRequest = remainingQs > 50 ? 50 : remainingQs;

      // 5. Fetch the calculated batch
      final questions = await _apiService.fetchQuestions(
        amount: amountToRequest,
        categoryId: widget.categoryId,
        difficulty: widget.difficulty,
        token: token,
      );

      if (questions.isEmpty) {
        throw Exception('No questions returned from API.');
      }

      // 6. Initialize a new session in cache
      _sessionData = _GameCacheData()
        ..questions = questions
        ..currentIndex = 0
        ..globalOffset = answeredCount
        ..totalQuestions = totalQs;

      _GameSessionManager.activeSessions[_sessionKey] = _sessionData!;

      _setupQuestion();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      // OpenTDB returns Code 1 if it lacks questions, Code 4 if token is empty. We catch both.
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

  void _setupQuestion() {
    if (_sessionData == null) return;
    final currentQuestion = _sessionData!.questions[_sessionData!.currentIndex];

    _sessionData!.shuffledAnswers = List.from(currentQuestion.incorrectAnswers);
    _sessionData!.shuffledAnswers.add(currentQuestion.correctAnswer);
    _sessionData!.shuffledAnswers.shuffle();

    _sessionData!.isAnswered = false;
    _sessionData!.selectedAnswer = null;
  }

  void _submitAnswer(String answer) async {
    if (_sessionData == null || _sessionData!.isAnswered) return;

    setState(() {
      _sessionData!.selectedAnswer = answer;
      _sessionData!.isAnswered = true;
    });

    final currentQuestion = _sessionData!.questions[_sessionData!.currentIndex];
    final bool isCorrect = answer == currentQuestion.correctAnswer;

    // Save statistics silently
    await _dbHelper.insertPlayStat(
      categoryId: widget.categoryId,
      difficulty: currentQuestion.difficulty,
      dayOfWeek: DateTime.now().weekday,
      isCorrect: isCorrect,
    );

    // Wait 2 seconds for visual feedback
    await Future.delayed(const Duration(seconds: 2));
    _nextQuestion();
  }

  void _nextQuestion() {
    if (!mounted || _sessionData == null) return;

    if (_sessionData!.currentIndex < _sessionData!.questions.length - 1) {
      setState(() {
        _sessionData!.currentIndex++;
        _setupQuestion();
      });
    } else {
      // Finished the current batch in memory. Fetch the next batch automatically!
      _startGame();
    }
  }

  // --- RESTART & END GAME LOGIC ---

  void _restartGame() {
    showDialog(
      context: context,
      // 1. Rename the inner context to 'dialogContext'
      builder: (dialogContext) => AlertDialog(
        title: const Text('Warning: Progress Reset'),
        content: const Text(
          'This will delete your progress for this category and set it to inactive. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            // 2. Use dialogContext to close the popup
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
            ),
            onPressed: () async {
              // 3. Use dialogContext to close the popup
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              // Reset Token in API
              final currentToken = PreferencesHelper.sessionToken;
              if (currentToken != null) {
                await _apiService.resetSessionToken(currentToken);
              }

              // Clear Local Stats & Cache
              await _dbHelper.resetCategoryStats(
                widget.categoryId,
                widget.difficulty,
              );
              _GameSessionManager.clear(widget.categoryId, widget.difficulty);

              // Set category to inactive
              await _dbHelper.setCategoryInactive(widget.categoryId);

              // 4. Use the SCREEN'S context to return to the Dashboard
              if (mounted) {
                Navigator.pop(context);
              }
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
      // 1. Rename the inner context to 'dialogContext'
      builder: (dialogContext) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: const Text(
          'You have completed all available questions for this category. '
          'Continuing will reset your progress and set the category to inactive.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 2. Pop the dialog first, then the screen
              Navigator.pop(dialogContext);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 3. Pop the dialog using its specific context
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
              _GameSessionManager.clear(widget.categoryId, widget.difficulty);
              await _dbHelper.setCategoryInactive(widget.categoryId);

              // 4. Pop the screen using the main context
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Color _getButtonColor(String answer) {
    if (_sessionData == null || !_sessionData!.isAnswered) return Colors.white;

    final correctAnswer =
        _sessionData!.questions[_sessionData!.currentIndex].correctAnswer;

    if (answer == correctAnswer) return Colors.green.shade300;
    if (answer == _sessionData!.selectedAnswer && answer != correctAnswer)
      return Colors.red.shade300;

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
                onPressed: _startGame,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessionData == null || _sessionData!.questions.isEmpty) {
      return const Center(child: Text('No questions available.'));
    }

    final currentQuestion = _sessionData!.questions[_sessionData!.currentIndex];

    // Calculate global question number based on past played + current batch index
    final int currentGlobalNumber =
        _sessionData!.globalOffset + _sessionData!.currentIndex + 1;
    final int totalQ = _sessionData!.totalQuestions;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Global Progress Indicator
          Text(
            'Question $currentGlobalNumber of ${totalQ > 0 ? totalQ : 'Unknown'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalQ > 0 ? (currentGlobalNumber / totalQ) : 0.0,
            backgroundColor: Colors.grey.shade200,
          ),

          const SizedBox(height: 32),

          Expanded(
            child: SingleChildScrollView(
              child: Text(
                currentQuestion.questionText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          ..._sessionData!.shuffledAnswers.map((answer) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                onPressed: _sessionData!.isAnswered
                    ? null
                    : () => _submitAnswer(answer),
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
                    color:
                        _sessionData!.isAnswered &&
                            answer == currentQuestion.correctAnswer
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
