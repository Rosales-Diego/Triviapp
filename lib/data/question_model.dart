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

  // Factory para convertir el JSON de la API a nuestro objeto Dart
  factory Question.fromJson(Map<String, dynamic> json) {
    // Función interna para decodificar el texto en Base64 a texto normal
    String decodeBase64(String str) {
      return utf8.decode(base64.decode(str));
    }

    return Question(
      category: decodeBase64(json['category']),
      difficulty: decodeBase64(json['difficulty']),
      questionText: decodeBase64(json['question']),
      correctAnswer: decodeBase64(json['correct_answer']),
      // Como las respuestas incorrectas vienen en una lista, iteramos sobre ellas
      incorrectAnswers: List<String>.from(
        json['incorrect_answers'].map((x) => decodeBase64(x)),
      ),
    );
  }
}
