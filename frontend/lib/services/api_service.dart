import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ORA PUNTIAMO AL CLOUD (Render)
  // Non più localhost!
  static const String baseUrl = 'https://leverage-backend-ht38.onrender.com';

  Future<Map<String, dynamic>> calculateWealth({
    required double benchmarkCost,
    required double moduleCost,
  }) async {
    final url = Uri.parse('$baseUrl/calculate');

    try {
      print("Tentativo di connessione a: $url");
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'benchmark_cost': benchmarkCost,
          'module_cost': moduleCost,
        }),
      );

      print("Risposta ricevuta: ${response.statusCode}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Errore del server: ${response.statusCode}');
      }
    } catch (e) {
      print("Errore di connessione: $e");
      throw Exception('Impossibile connettersi al Server Cloud.');
    }
  }
}