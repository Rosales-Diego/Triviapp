import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/question_model.dart';

class TriviaApiService {
  // Base URL for the API
  final String _baseUrl = 'https://opentdb.com';

  // --- 1. Category and Metadata Methods ---

  // Fetches the list of all available categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final url = Uri.parse('$_baseUrl/api_category.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Returns a list of maps containing 'id' and 'name'
      return List<Map<String, dynamic>>.from(data['trivia_categories']);
    } else {
      throw Exception('Failed to load categories from API');
    }
  }

  // Fetches the exact count of questions for a specific category
  Future<Map<String, dynamic>> fetchCategoryQuestionCount(
    int categoryId,
  ) async {
    final url = Uri.parse('$_baseUrl/api_count.php?category=$categoryId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Returns a map with total_question_count, total_easy_question_count, etc.
      return data['category_question_count'];
    } else {
      throw Exception('Failed to load question count for category $categoryId');
    }
  }

  // --- 2. Session Token Methods ---

  // Requests a brand new session token
  Future<String> requestSessionToken() async {
    final url = Uri.parse('$_baseUrl/api_token.php?command=request');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['response_code'] == 0) {
        return data['token'];
      } else {
        throw Exception('API Error: Failed to generate session token');
      }
    } else {
      throw Exception('HTTP Error: Failed to connect to token service');
    }
  }

  // Resets an existing session token (used when the token is empty / code 4)
  Future<bool> resetSessionToken(String token) async {
    final url = Uri.parse('$_baseUrl/api_token.php?command=reset&token=$token');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Returns true if the reset was successful
      return data['response_code'] == 0;
    } else {
      throw Exception('HTTP Error: Failed to reset session token');
    }
  }

  // --- 3. Fetch Questions Method ---

  // Fetches questions with optional filters (category, difficulty) and session token
  Future<List<Question>> fetchQuestions({
    int amount = 10,
    int? categoryId,
    String? difficulty,
    String? token,
  }) async {
    // Base URL explicitly requesting Base64 encoding to avoid special character issues
    String urlString = '$_baseUrl/api.php?amount=$amount&encode=base64';

    // Append optional parameters if they are provided
    // categoryId 0 is our custom logic for "All Categories"
    if (categoryId != null && categoryId != 0) {
      urlString += '&category=$categoryId';
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      urlString += '&difficulty=$difficulty';
    }
    if (token != null && token.isNotEmpty) {
      urlString += '&token=$token';
    }

    final url = Uri.parse(urlString);

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final int responseCode = data['response_code'];

        if (responseCode == 0) {
          // Success: map JSON to Question objects
          final List<dynamic> results = data['results'];
          return results.map((json) => Question.fromJson(json)).toList();
        } else if (responseCode == 4) {
          // Token Empty: We throw a specific exception so the UI knows it's time to restart
          throw Exception('TOKEN_EMPTY');
        } else {
          // Handle other API error codes (1, 2, 3, 5)
          throw Exception('API Error Code: $responseCode');
        }
      } else {
        throw Exception(
          'HTTP Error: Unable to connect to server (${response.statusCode})',
        );
      }
    } catch (e) {
      // Re-throw the exception to be handled by the UI or calling function
      rethrow;
    }
  }
}
