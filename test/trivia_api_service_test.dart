import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triviapp/services/trivia_api_service.dart';

void main() {
  group('TriviaApiService Network Mock Tests', () {
    test(
      'fetchCategories returns a list of categories on successful HTTP response',
      () async {
        // 1. Arrange: Create a MockClient that intercepts the request
        final mockClient = MockClient((request) async {
          // Assert that the service is calling the correct URL
          expect(
            request.url.toString(),
            'https://opentdb.com/api_category.php',
          );

          // Create a fake JSON response simulating the Open Trivia DB format
          final jsonResponse = '''
        {
          "trivia_categories": [
            {"id": 9, "name": "General Knowledge"},
            {"id": 10, "name": "Entertainment: Books"}
          ]
        }
        ''';

          // Return an HTTP 200 OK with the fake JSON
          return http.Response(jsonResponse, 200);
        });

        // 2. Act: Inject the mock client into our service
        final apiService = TriviaApiService(client: mockClient);
        final categories = await apiService.fetchCategories();

        // 3. Assert: Verify the service correctly parsed our fake JSON
        expect(categories, isA<List<Map<String, dynamic>>>());
        expect(categories.length, 2);
        expect(categories[0]['id'], 9);
        expect(categories[0]['name'], 'General Knowledge');
        expect(categories[1]['id'], 10);
        expect(categories[1]['name'], 'Entertainment: Books');
      },
    );

    test(
      'fetchCategories throws an exception on HTTP error (e.g. 404)',
      () async {
        // Arrange: Create a MockClient that simulates a server error
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final apiService = TriviaApiService(client: mockClient);

        // Act & Assert: Verify that the service throws an Exception
        expect(
          () async => await apiService.fetchCategories(),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('fetchCategoryQuestionCount returns count on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://opentdb.com/api_count.php?category=9');
        final jsonResponse = '{"category_id": 9, "category_question_count": {"total_question_count": 304, "total_easy_question_count": 122, "total_medium_question_count": 128, "total_hard_question_count": 54}}';
        return http.Response(jsonResponse, 200);
      });

      final apiService = TriviaApiService(client: mockClient);
      final count = await apiService.fetchCategoryQuestionCount(9);

      expect(count['total_question_count'], 304);
      expect(count['total_easy_question_count'], 122);
    });

    test('requestSessionToken returns a token string on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://opentdb.com/api_token.php?command=request');
        final jsonResponse = '{"response_code": 0, "response_message": "Token Generated Successfully!", "token": "mock_token_abc123"}';
        return http.Response(jsonResponse, 200);
      });

      final apiService = TriviaApiService(client: mockClient);
      final token = await apiService.requestSessionToken();

      expect(token, 'mock_token_abc123');
    });

    test('resetSessionToken returns true on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://opentdb.com/api_token.php?command=reset&token=mock_token_abc123');
        final jsonResponse = '{"response_code": 0, "token": "mock_token_abc123"}';
        return http.Response(jsonResponse, 200);
      });

      final apiService = TriviaApiService(client: mockClient);
      final success = await apiService.resetSessionToken('mock_token_abc123');

      expect(success, true);
    });

    test('fetchQuestions returns a list of Questions on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString().contains('amount=10'), true);
        expect(request.url.toString().contains('category=9'), true);
        expect(request.url.toString().contains('difficulty=easy'), true);
        expect(request.url.toString().contains('encode=base64'), true);
        
        // Base64 encoded payload simulating 'General Knowledge', 'easy', 'Question?', 'Yes', ['No']
        final jsonResponse = '''
        {
          "response_code": 0,
          "results": [
            {
              "category": "R2VuZXJhbCBLbm93bGVkZ2U=",
              "type": "Ym9vbGVhbg==",
              "difficulty": "ZWFzeQ==",
              "question": "UXVlc3Rpb24/",
              "correct_answer": "WWVz",
              "incorrect_answers": ["Tm8="]
            }
          ]
        }
        ''';
        return http.Response(jsonResponse, 200);
      });

      final apiService = TriviaApiService(client: mockClient);
      final questions = await apiService.fetchQuestions(
        amount: 10,
        categoryId: 9,
        difficulty: 'easy',
      );

      expect(questions.length, 1);
      expect(questions[0].category, 'General Knowledge');
      expect(questions[0].difficulty, 'easy');
      expect(questions[0].questionText, 'Question?');
      expect(questions[0].correctAnswer, 'Yes');
      expect(questions[0].incorrectAnswers.length, 1);
      expect(questions[0].incorrectAnswers[0], 'No');
    });

    test('fetchQuestions throws TOKEN_EMPTY exception on response code 4', () async {
      final mockClient = MockClient((request) async {
        final jsonResponse = '{"response_code": 4, "results": []}';
        return http.Response(jsonResponse, 200);
      });

      final apiService = TriviaApiService(client: mockClient);

      expect(
        () async => await apiService.fetchQuestions(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('TOKEN_EMPTY'))),
      );
    });
  });
}
