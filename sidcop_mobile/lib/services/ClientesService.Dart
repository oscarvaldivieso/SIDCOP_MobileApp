import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';


class ClientesService {
  // --- Ubicaciones ---
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

      developer.log('Get CuentasPorCobrar Response Status: [33m[1m${response.statusCode}[0m');
      developer.log('Get CuentasPorCobrar Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) {
            return data;
          } else {
            throw Exception('La clave "data" no es una lista.');
          }
        } else {
          throw Exception('Respuesta inesperada del servidor: falta la clave "data".');
        }
      } else {
        throw Exception(
          'Error en la solicitud: Código [33m[1m${response.statusCode}[0m, Respuesta: ${response.body}',
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

 Future<List<Map<String, dynamic>>> getDepartamentos() async {
    final url = Uri.parse('$_apiServer/Departamentos/Listar');
    developer.log('Get Departamentos Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );
      developer.log('Get Departamentos Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Get Departamentos Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMunicipios() async {
    final url = Uri.parse('$_apiServer/Municipios/Listar');
    developer.log('Get Municipios Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Municipios Response Status: \${response.statusCode}');
      developer.log('Get Municipios Response Body: \${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> municipiosList = jsonDecode(response.body);
        return municipiosList.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Municipios Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getColonias() async {
    final url = Uri.parse('$_apiServer/Colonia/Listar');
    developer.log('Get Colonias Request URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get Colonias Response Status: \${response.statusCode}');
      developer.log('Get Colonias Response Body: \${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> coloniasList = jsonDecode(response.body);
        return coloniasList.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Error en la solicitud: Código \${response.statusCode}, Respuesta: \${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Colonias Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }



}
