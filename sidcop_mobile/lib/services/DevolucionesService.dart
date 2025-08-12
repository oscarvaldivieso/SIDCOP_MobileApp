import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';

class DevolucionesService {
  final String _endpoint = 'Devoluciones';
  final String _apiServer;
  final String _apiKey;

  DevolucionesService() : _apiServer = apiServer, _apiKey = apikey;

  Future<http.Response> get(String endpoint) async {
    final url = '$_apiServer/$endpoint';
    print('GET Request to: $url');
    print(
      'Headers: ${{
        'Content-Type': 'application/json',
        'X-Api-Key': '${_apiKey.substring(0, 5)}...', // Show first 5 chars for security
      }}',
    );

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      return response;
    } catch (e) {
      print('Error in GET request: $e');
      rethrow;
    }
  }

  Future<List<DevolucionesViewModel>> listarDevoluciones() async {
    print('=== listarDevoluciones() called ===');
    try {
      final response = await get('Devoluciones/Listar');

      if (response.statusCode == 200) {
        print('Response status is 200, parsing JSON...');
        final List<dynamic> data = json.decode(response.body);
        print('Parsed ${data.length} items from response');

        if (data.isEmpty) {
          print('No data returned from API');
        } else {
          print('First item in response: ${data.first}');
        }

        final result = data
            .map((json) => DevolucionesViewModel.fromJson(json))
            .toList();

        print(
          'Successfully mapped ${result.length} DevolucionesViewModel objects',
        );
        return result;
      } else {
        final errorMsg =
            'Error al listar devoluciones: ${response.statusCode} - ${response.body}';
        print(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error en listarDevoluciones: $e';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  }

  Future<List<DevolucionDetalleModel>> getDevolucionDetalles(int devoId) async {
    print('=== getDevolucionDetalles() called for devoId: $devoId ===');
    try {
      final response = await get('DevolucionesDetalles/Buscar/$devoId');

      if (response.statusCode == 200) {
        print('Response status is 200, parsing JSON...');
        final List<dynamic> data = json.decode(response.body);
        print('Parsed ${data.length} items from response');

        final result = data
            .map((json) => DevolucionDetalleModel.fromJson(json))
            .toList();

        print(
          'Successfully mapped ${result.length} DevolucionDetalleModel objects',
        );
        return result;
      } else {
        final errorMsg =
            'Error al obtener detalles de devolución: ${response.statusCode} - ${response.body}';
        print(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error en getDevolucionDetalles: $e';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  }
}
