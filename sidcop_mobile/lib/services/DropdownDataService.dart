import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';

class DropdownDataService {
  final String _baseUrl = '$apiServer';
  final String _apiKey = 'bdccf3f3-d486-4e1e-ab44-74081aefcdbc';

  Future<List<dynamic>> getCanales() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/Canal/Listar'),
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw Exception('Failed to load canales');
      }
    } catch (e) {
      print('Error fetching canales: $e');
      return [];
    }
  }

  Future<List<dynamic>> getEstadosCiviles() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/EstadosCiviles/Listar'),
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw Exception('Failed to load estados civiles');
      }
    } catch (e) {
      print('Error fetching estados civiles: $e');
      return [];
    }
  }

  Future<List<dynamic>> getRutas() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/Rutas/Listar'),
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw Exception('Failed to load rutas');
      }
    } catch (e) {
      print('Error fetching rutas: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertCliente(Map<String, dynamic> clienteData) async {
    try {
      // Set default values
      clienteData['usua_Creacion'] = 1;
      clienteData['clie_FechaCreacion'] = DateTime.now().toIso8601String();
      // clie_ImagenDelNegocio will be set by the client creation form
      
      final response = await http.post(
        Uri.parse('$_baseUrl/Cliente/Insertar'),
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(clienteData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to insert cliente');
      }
    } catch (e) {
      print('Error inserting cliente: $e');
      rethrow;
    }
  }
}
