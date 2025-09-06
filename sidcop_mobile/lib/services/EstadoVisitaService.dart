import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/EstadoVisitaModel.dart';

class EstadoVisitaService {
  static const String _baseUrl = 'http://200.59.27.115:8091';
  static const String _apiKey = 'bdccf3f3-d486-4e1e-ab44-74081aefcdbc';

  Future<List<EstadoVisitaModel>> listar() async {
    final url = Uri.parse('$_baseUrl/EstadoVisita/Listar');
    final response = await http.get(
      url,
      headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => EstadoVisitaModel.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener EstadoVisita: ${response.statusCode}');
    }
  }
}
