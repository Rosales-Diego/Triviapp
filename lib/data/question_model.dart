import 'dart:convert';

class Question {
  final String category;
  final String difficulty;
  final String questionText;
  final String correctAnswer;
  final List<String> incorrectAnswers;

  Question({
    required this.category,
    required this.difficulty,
    required this.questionText,
    required this.correctAnswer,
    required this.incorrectAnswers,
  });

  // Factory to convert the JSON from the API to our Dart object
  factory Question.fromJson(Map<String, dynamic> json) {
    // Internal function to decode Base64 text to normal text
    String decodeBase64(String str) {
      return utf8.decode(base64.decode(str));
    }

    return Question(
      category: decodeBase64(json['category']),
      difficulty: decodeBase64(json['difficulty']),
      questionText: decodeBase64(json['question']),
      correctAnswer: decodeBase64(json['correct_answer']),
      // Since the incorrect answers come in a list, we iterate over them
      incorrectAnswers: List<String>.from(
        json['incorrect_answers'].map((x) => decodeBase64(x)),
      ),
    );
  }
}
