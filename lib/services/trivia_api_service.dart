import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/question_model.dart';

class TriviaApiService {
  final String _baseUrl = 'https://opentdb.com';

  // Static variable to track the exact time of the last API request across the whole app
  static DateTime? _lastRequestTime;

  // --- Throttle Mechanism ---
  // Guarantees at least 5 seconds between any network calls to prevent IP bans
  Future<void> _throttleRequest() async {
    if (_lastRequestTime == null) {
      _lastRequestTime = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime!);

    if (elapsed.inMilliseconds < 5000) {
      // Calculate exactly how much time is left to reach 5 seconds
      final waitTime = const Duration(milliseconds: 5000) - elapsed;

      // Update the last request time projecting into the future
      // This queues multiple rapid requests perfectly 5 seconds apart
      _lastRequestTime = _lastRequestTime!.add(
        const Duration(milliseconds: 5000),
      );

      // Pause execution here until the wait time is over
      await Future.delayed(waitTime);
    } else {
      _lastRequestTime = now;
    }
  }

  // --- API Methods ---

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    await _throttleRequest(); // <-- Apply throttle before every request
    final url = Uri.parse('$_baseUrl/api_category.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['trivia_categories']);
    } else {
      throw Exception('Failed to load categories from API');
    }
  }

  Future<Map<String, dynamic>> fetchCategoryQuestionCount(
    int categoryId,
  ) async {
    await _throttleRequest();
    final url = Uri.parse('$_baseUrl/api_count.php?category=$categoryId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['category_question_count'];
    } else {
      throw Exception('Failed to load question count for category $categoryId');
    }
  }

  Future<String> requestSessionToken() async {
    await _throttleRequest();
    final url = Uri.parse('$_baseUrl/api_token.php?command=request');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['response_code'] == 0) return data['token'];
      throw Exception('API Error: Failed to generate session token');
    } else {
      throw Exception('HTTP Error: Failed to connect to token service');
    }
  }

  Future<bool> resetSessionToken(String token) async {
    await _throttleRequest();
    final url = Uri.parse('$_baseUrl/api_token.php?command=reset&token=$token');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['response_code'] == 0;
    } else {
      throw Exception('HTTP Error: Failed to reset session token');
    }
  }

  Future<List<Question>> fetchQuestions({
    int amount = 10,
    int? categoryId,
    String? difficulty,
    String? token,
  }) async {
    await _throttleRequest();

    String urlString = '$_baseUrl/api.php?amount=$amount&encode=base64';

    if (categoryId != null && categoryId != 0) {
      urlString += '&category=$categoryId';
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      urlString += '&difficulty=$difficulty';
    }
    if (token != null && token.isNotEmpty) urlString += '&token=$token';

    final url = Uri.parse(urlString);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final int responseCode = data['response_code'];

      if (responseCode == 0) {
        final List<dynamic> results = data['results'];
        return results.map((json) => Question.fromJson(json)).toList();
      } else if (responseCode == 4) {
        throw Exception('TOKEN_EMPTY');
      } else {
        throw Exception('API Error Code: $responseCode');
      }
    } else {
      throw Exception('HTTP Error: Unable to connect to server');
    }
  }
}
