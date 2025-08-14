import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';

class FacturaService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getFacturas() async {
    final url = Uri.parse('$_apiServer/Facturas/Listar');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'X-Api-Key': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List;
        }
        throw Exception(data['message'] ?? 'Error al cargar facturas');
      } else {
        throw Exception('Error al cargar facturas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }
}
