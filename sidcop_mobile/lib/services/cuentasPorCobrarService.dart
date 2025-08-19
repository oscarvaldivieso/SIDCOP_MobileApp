import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';

class CuentasXCobrarService {
  // --- Configuración del API ---
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<Map<String, dynamic>> getClienteCreditInfo(int clienteId) async {
    final url = Uri.parse('$_apiServer/Cliente/Buscar/$clienteId');
    developer.log('Get Cliente Credit Info Request URL: $url');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log(
        'Get Cliente Credit Info Response Status: ${response.statusCode}',
      );
      developer.log('Get Cliente Credit Info Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          // Calculate available credit
          final limiteCredito = (decoded['clie_LimiteCredito'] as num?)?.toDouble() ?? 0.0;
          final saldo = (decoded['clie_Saldo'] as num?)?.toDouble() ?? 0.0;
          final creditoDisponible = (limiteCredito - saldo).clamp(0, limiteCredito);
          
          return {
            'limiteCredito': limiteCredito,
            'saldoActual': saldo,
            'creditoDisponible': creditoDisponible,
            'clienteNombre': '${decoded['clie_Nombres'] ?? ''} ${decoded['clie_Apellidos'] ?? ''}'.trim(),
            'nombreNegocio': decoded['clie_NombreNegocio']?.toString() ?? ''
          };
        } else {
          throw Exception('Respuesta del servidor en formato incorrecto');
        }
      } else {
        throw Exception(
          'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Cliente Credit Info Error: $e');
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

  Future<Map<String, dynamic>> getCuentaPorCobrarDetalle(int cuentaId) async {
    final url = Uri.parse('$_apiServer/CuentasPorCobrar/Detalle/$cuentaId');
    developer.log('Get CuentaPorCobrar Detalle Request URL: $url');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      developer.log('Get CuentaPorCobrar Detalle Response Status: ${response.statusCode}');
      developer.log('Get CuentaPorCobrar Detalle Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return decoded['data'];
        } else if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          throw Exception('Respuesta inesperada del servidor: formato no reconocido.');
        }
      } else {
        throw Exception('Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}');
      }
    } catch (e) {
      developer.log('Get CuentaPorCobrar Detalle Error: $e');
      throw Exception('Error en la solicitud: $e');
    }
  }
}