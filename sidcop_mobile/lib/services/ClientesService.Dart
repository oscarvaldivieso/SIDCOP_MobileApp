import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';


class ClientesService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getClientes() async{

    final url = Uri.parse('$_apiServer/Cliente/Listar');
    developer.log('Get Clientes Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Clientes Response Status: ${response.statusCode}');
      developer.log('Get Clientes Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> clientesList = jsonDecode(response.body);
        return clientesList;
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Clientes Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  Future<Map<String, dynamic>> getClienteById(int id) async {
    final url = Uri.parse('$_apiServer/Cliente/Buscar/$id');
    developer.log('Get Cliente by ID Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Cliente by ID Response Status: ${response.statusCode}');
      developer.log('Get Cliente by ID Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Error al obtener el cliente: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Cliente by ID Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  Future<List<dynamic>> getDireccionesPorCliente() async {
    final url = Uri.parse('$_apiServer/DireccionesPorCliente/Listar');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return data is List ? data : [data];
        } catch (e) {
          return [];
        }
      } else {
        throw Exception('Error en la solicitud: Código ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getCuentasPorCobrar() async {

    final url = Uri.parse('$_apiServer/CuentasPorCobrar/Listar');
    developer.log('Get CuentasPorCobrar Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get CuentasPorCobrar Response Status: ${response.statusCode}');
      developer.log('Get CuentasPorCobrar Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> cuentasPorCobrarList = jsonDecode(response.body);
        return cuentasPorCobrarList;
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get CuentasPorCobrar Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  Future<List<dynamic>> getDireccionesCliente(int clienteId) async {
    final url = Uri.parse('$_apiServer/DireccionesPorCliente/Buscar/$clienteId');
    developer.log('Get Direcciones Cliente Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Direcciones Cliente Response Status: ${response.statusCode}');
      developer.log('Get Direcciones Cliente Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [data]; // Return as list even if single item
      } else {
        throw Exception('Error al obtener las direcciones del cliente: Código ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Get Direcciones Cliente Error: $e');
      throw Exception('Error al obtener las direcciones del cliente: $e');
    }
  }
}
