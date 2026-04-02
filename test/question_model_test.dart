import 'package:flutter_test/flutter_test.dart';
import 'package:triviapp/data/question_model.dart';

void main() {
  group('Question Model Tests', () {
    test('Question.fromJson correctly decodes Base64 data', () {
      // 1. Arrange: A simulated JSON response from the API (Base64 encoded)
      // "Science", "easy", "Is water wet?", "Yes", ["No", "Maybe"]
      final Map<String, dynamic> mockJson = {
        "category": "U2NpZW5jZQ==",
        "difficulty": "ZWFzeQ==",
        "question": "SXMgd2F0ZXIgd2V0Pw==",
        "correct_answer": "WWVz",
        "incorrect_answers": ["Tm8=", "TWF5YmU="],
      };

      // 2. Act: Convert the JSON to our Question object
      final question = Question.fromJson(mockJson);

      // 3. Assert: Verify the decoded strings match the expected plain text
      expect(question.category, 'Science');
      expect(question.difficulty, 'easy');
      expect(question.questionText, 'Is water wet?');
      expect(question.correctAnswer, 'Yes');
      expect(question.incorrectAnswers.length, 2);
      expect(question.incorrectAnswers[0], 'No');
      expect(question.incorrectAnswers[1], 'Maybe');
    });
  });
}
