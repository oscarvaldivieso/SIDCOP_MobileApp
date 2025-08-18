import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';

class CuentasXCobrarService {
  // --- Configuración del API ---
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getCuentasPorCobrar() async {
    final url = Uri.parse('$_apiServer/CuentasPorCobrar/Listar');
    developer.log('Get CuentasPorCobrar Request URL: $url');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log(
        'Get CuentasPorCobrar Response Status: ${response.statusCode}',
      );
      developer.log('Get CuentasPorCobrar Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Verificar si la respuesta tiene la estructura con "data"
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) {
            return data;
          } else {
            throw Exception('La clave "data" no es una lista.');
          }
        } 
        // Si no tiene "data", asumir que es directamente una lista
        else if (decoded is List) {
          return decoded;
        } else {
          throw Exception(
            'Respuesta inesperada del servidor: formato no reconocido.',
          );
        }
      } else {
        throw Exception(
          'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get CuentasPorCobrar Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

Future<CuentasXCobrar?> getDetalleCuentaPorCobrar(int cpCoId) async {
  final url = Uri.parse('$_apiServer/CuentasPorCobrar/Detalle/$cpCoId');
  developer.log('Get Detalle CuentaPorCobrar Request URL: $url');
  
  try {
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
    );

    developer.log(
      'Get Detalle CuentaPorCobrar Response Status: ${response.statusCode}',
    );
    developer.log('Get Detalle CuentaPorCobrar Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      
      // Verificar si la respuesta tiene la estructura con "data"
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return CuentasXCobrar.fromJson(data);
        } else {
          throw Exception('La clave "data" no es un objeto válido.');
        }
      } 
      // Si no tiene "data", asumir que es directamente el objeto
      else if (decoded is Map<String, dynamic>) {
        return CuentasXCobrar.fromJson(decoded);
      } else {
        throw Exception(
          'Respuesta inesperada del servidor: formato no reconocido.',
        );
      }
    } else if (response.statusCode == 404) {
      // Manejar caso donde no se encuentra la cuenta
      return null;
    } else {
      throw Exception(
        'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
      );
    }
  } catch (e) {
    developer.log('Get Detalle CuentaPorCobrar Error: $e');
    throw Exception('Error en la solicitud: $e');
  }
}



  // Método agregado para obtener el resumen por cliente
  Future<List<dynamic>> getResumenCliente() async {
    final url = Uri.parse('$_apiServer/CuentasPorCobrar/ResumenCliente');
    developer.log('Get ResumenCliente Request URL: $url');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log(
        'Get ResumenCliente Response Status: ${response.statusCode}',
      );
      developer.log('Get ResumenCliente Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Verificar si la respuesta tiene la estructura con "data"
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) {
            return data;
          } else {
            throw Exception('La clave "data" no es una lista.');
          }
        } 
        // Si no tiene "data", asumir que es directamente una lista
        else if (decoded is List) {
          return decoded;
        } else {
          throw Exception(
            'Respuesta inesperada del servidor: formato no reconocido.',
          );
        }
      } else {
        throw Exception(
          'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get ResumenCliente Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }

// Agregar este método a tu CuentasXCobrarService

Future<List<dynamic>> getTimelineCliente(int clienteId) async {
  final url = Uri.parse('$_apiServer/CuentasPorCobrar/timeLineCliente/$clienteId');
  developer.log('Get Timeline Cliente Request URL: $url');
  
  try {
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
    );

    developer.log(
      'Get Timeline Cliente Response Status: ${response.statusCode}',
    );
    developer.log('Get Timeline Cliente Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      
      // Verificar si la respuesta tiene la estructura con "data"
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          return data;
        } else if (data is Map) {
          // Si es un solo objeto, lo convertimos en una lista
          return [data];
        } else {
          throw Exception('La clave "data" no es una lista o mapa válido.');
        }
      } 
      // Si no tiene "data", asumir que es directamente una lista o mapa
      else if (decoded is List) {
        return decoded;
      } else if (decoded is Map) {
        return [decoded];
      } else {
        throw Exception(
          'Respuesta inesperada del servidor: formato no reconocido.',
        );
      }
    } else {
      throw Exception(
        'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
      );
    }
  } catch (e) {
    developer.log('Get Timeline Cliente Error: $e');
    throw Exception('Error en la solicitud: $e');
  }
 }

}