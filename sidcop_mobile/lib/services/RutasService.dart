import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';

class RutasService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getRutas() async {
    final url = Uri.parse('$_apiServer/Rutas/Listar');
    developer.log('Get Rutas Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Rutas Response Status: ${response.statusCode}');
      developer.log('Get Rutas Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> rutasList = jsonDecode(response.body);
        return rutasList;
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Rutas Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }
  Future<List<dynamic>> createRuta(Map<String, dynamic> rutaData) async {
    final url = Uri.parse('$_apiServer/Rutas/Crear');
    developer.log('Create Ruta Request URL: $url');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(rutaData),
      );

      developer.log('Create Ruta Response Status: ${response.statusCode}');
      developer.log('Create Ruta Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final List<dynamic> createdRuta = jsonDecode(response.body);
        return createdRuta;
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Create Ruta Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }
  Future<List<dynamic>> updateRuta(int rutaId , Map<String, dynamic> rutaData) async {
    final url = Uri.parse('$_apiServer/Rutas/Modificar/$rutaId');
    developer.log('Update Ruta Request URL: $url');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(rutaData),
      );

      developer.log('Update Ruta Response Status: ${response.statusCode}');
      developer.log('Update Ruta Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> updatedRuta = jsonDecode(response.body);
        return updatedRuta;
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Update Ruta Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }
}