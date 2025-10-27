import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/services/UsuarioService.dart';

class RutasService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getRutas() async {
    final url = Uri.parse('$_apiServer/Rutas/Listar');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        final List<dynamic> rutasList = jsonDecode(response.body);

        // Filtrar por rutasDelDia - si está vacío, no mostrar rutas
        final rutasDelDiaIds = await UsuarioService.obtenerRutasDelDiaIds();

        if (rutasDelDiaIds.isEmpty) {
          return [];
        }

        final rutasFiltradas = rutasList.where((ruta) {
          final rutaId = ruta['ruta_Id'] ?? ruta['rutaId'] ?? ruta['Ruta_Id'];
          return rutasDelDiaIds.contains(rutaId);
        }).toList();

        return rutasFiltradas;
      } else {
        throw Exception('Error en la solicitud: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en la solicitud: $e');
    }
  }

  Future<List<dynamic>> createRuta(Map<String, dynamic> rutaData) async {
    final url = Uri.parse('$_apiServer/Rutas/Crear');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(rutaData),
      );

      if (response.statusCode == 201) {
        final List<dynamic> createdRuta = jsonDecode(response.body);
        return createdRuta;
      } else {
        throw Exception('Error en la solicitud: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en la solicitud: $e');
    }
  }

  Future<List<dynamic>> updateRuta(
    int rutaId,
    Map<String, dynamic> rutaData,
  ) async {
    final url = Uri.parse('$_apiServer/Rutas/Modificar/$rutaId');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
        body: jsonEncode(rutaData),
      );

      if (response.statusCode == 200) {
        final List<dynamic> updatedRuta = jsonDecode(response.body);
        return updatedRuta;
      } else {
        throw Exception('Error en la solicitud: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en la solicitud: $e');
    }
  }
}
