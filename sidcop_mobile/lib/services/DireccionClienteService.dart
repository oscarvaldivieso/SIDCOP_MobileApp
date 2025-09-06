import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';

class DireccionClienteService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  // Get list of colonies
  Future<List<Colonia>> getColonias() async {
    final url = Uri.parse('$_apiServer/Colonia/Listar');
    developer.log('Get Colonias Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Colonias Response Status: ${response.statusCode}');
      developer.log('Get Colonias Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => Colonia.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener las colonias: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Colonias Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  // Listar direcciones por cliente
  Future<List<DireccionCliente>> getDireccionesPorCliente() async {
    final url = Uri.parse('$_apiServer/DireccionesPorCliente/Listar');
    developer.log('Listar DireccionesPorCliente Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {'accept': '*/*', 'X-Api-Key': _apiKey},
      );

      developer.log(
        'Listar DireccionesPorCliente Response Status: ${response.statusCode}',
      );
      developer.log(
        'Listar DireccionesPorCliente Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => DireccionCliente.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener las direcciones: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Listar DireccionesPorCliente Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  // Insert a new client address
  Future<Map<String, dynamic>> insertDireccionCliente(
    DireccionCliente direccion,
  ) async {
    final url = Uri.parse('$_apiServer/DireccionesPorCliente/Insertar');
    developer.log('Insert DireccionCliente Request URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(direccion.toJson()),
      );

      developer.log('Insert DireccionCliente Status: ${response.statusCode}');
      developer.log('Insert DireccionCliente Response: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Error al insertar la dirección: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Insert DireccionCliente Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  // Insert multiple addresses for a client
  Future<List<Map<String, dynamic>>> insertDireccionesCliente(
    List<DireccionCliente> direcciones,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final direccion in direcciones) {
      try {
        final result = await insertDireccionCliente(direccion);
        results.add(result);
      } catch (e) {
        developer.log('Error inserting address: $e');
        results.add({
          'success': false,
          'error': e.toString(),
          'direccion': direccion.toJson(),
        });
      }
    }

    return results;
  }
}
