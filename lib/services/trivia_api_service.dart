import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/question_model.dart';

class TriviaApiService {
  // URL base pidiendo explícitamente el formato base64
  final String _baseUrl = 'https://opentdb.com/api.php?encode=base64';

  Future<List<Question>> fetchQuestions({int amount = 10}) async {
    // Construimos la URL final con la cantidad de preguntas
    final url = Uri.parse('$_baseUrl&amount=$amount');

    try {
      final response = await http.get(url);

      // Verificamos si la conexión a internet fue exitosa (Código HTTP 200)
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // La documentación dice que el "response_code" 0 es éxito total
        if (data['response_code'] == 0) {
          final List<dynamic> results = data['results'];

          // Mapeamos la lista de JSONs a nuestra lista de objetos Question
          return results.map((json) => Question.fromJson(json)).toList();
        } else {
          // Manejo de los códigos de error de la API (1, 2, 3, 4, 5)
          throw Exception(
            'Error de la API Trivia: Código ${data['response_code']}',
          );
        }
      } else {
        throw Exception(
          'Error HTTP: No se pudo conectar al servidor (${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Excepción capturada: $e');
    }
  }
}
