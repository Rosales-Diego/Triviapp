import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/question_model.dart';

class TriviaApiService {
  final String _baseUrl = 'https://opentdb.com';

  // 1. Add an injectable client variable
  final http.Client _client;

  static DateTime? _lastRequestTime;

  // 2. Modify the constructor to accept the client.
  // If no client is provided, it defaults to a standard http.Client()
  TriviaApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> _throttleRequest() async {
    if (_lastRequestTime == null) {
      _lastRequestTime = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime!);

    if (elapsed.inMilliseconds < 5000) {
      final waitTime = const Duration(milliseconds: 5000) - elapsed;
      _lastRequestTime = _lastRequestTime!.add(
        const Duration(milliseconds: 5000),
      );
      await Future.delayed(waitTime);
    } else {
      _lastRequestTime = now;
    }
  }

  // --- API Methods ---

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    await _throttleRequest();
    final url = Uri.parse('$_baseUrl/api_category.php');

    // 3. Replace http.get with _client.get in ALL methods
    final response = await _client.get(url);

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

    final response = await _client.get(url);

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

    final response = await _client.get(url);

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

    final response = await _client.get(url);

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

    if (categoryId != null && categoryId != 0)
      urlString += '&category=$categoryId';
    if (difficulty != null && difficulty.isNotEmpty)
      urlString += '&difficulty=$difficulty';
    if (token != null && token.isNotEmpty) urlString += '&token=$token';

    final url = Uri.parse(urlString);

    final response = await _client.get(url);

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
