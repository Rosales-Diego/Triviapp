import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triviapp/services/trivia_api_service.dart';

void main() {
  group('API Rate Limiter (Throttle) Tests', () {
    setUp(() {
      // Reset the timer before every test to ensure a clean state
      TriviaApiService.resetThrottleForTesting();
    });

    test('Concurrent requests are perfectly spaced by 5 seconds', () async {
      // 1. Arrange: Create a MockClient that responds instantly
      final mockClient = MockClient((request) async {
        final jsonResponse = '{"trivia_categories": []}';
        return http.Response(jsonResponse, 200);
      });

      final apiService = TriviaApiService(client: mockClient);

      // 2. Act: Start a stopwatch and fire 3 requests SIMULTANEOUSLY
      final stopwatch = Stopwatch()..start();

      // Future.wait executes all futures at the exact same time
      await Future.wait([
        apiService.fetchCategories(), // Request 1
        apiService.fetchCategories(), // Request 2
        apiService.fetchCategories(), // Request 3
      ]);

      stopwatch.stop();

      // 3. Assert:
      // R1 = 0s delay
      // R2 = 5s delay
      // R3 = 10s delay
      // Total elapsed time must be at least 10,000 milliseconds
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10000));

      print(
        'Total time for 3 concurrent requests: ${stopwatch.elapsedMilliseconds} ms',
      );
    });
  });
}
