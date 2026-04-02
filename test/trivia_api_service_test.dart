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
  });
}
