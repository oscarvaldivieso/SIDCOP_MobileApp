// Versión mejorada del servicio con mejor debugging y validación

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/models/ventas/PagosCXCViewModel.dart';
import 'package:sidcop_mobile/models/FormasDePagoViewModel.dart';

class PagoCuentasXCobrarService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  // Obtener formas de pago disponibles
  Future<List<FormaPago>> getFormasPago() async {
    try {
      final url = Uri.parse('$_apiServer/FormaDePago/Listar');
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey,
      };

      developer.log('Obteniendo formas de pago - URL: $url');

      final response = await http.get(url, headers: headers);

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) {
            return data.map((item) => FormaPago.fromJson(item)).toList();
          } else {
            throw Exception('La clave "data" no es una lista.');
          }
        } 
        else if (decoded is List) {
          return decoded.map((item) => FormaPago.fromJson(item)).toList();
        } else {
          throw Exception('Respuesta inesperada del servidor: formato no reconocido.');
        }
      } else {
        developer.log('Error al obtener formas de pago: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      developer.log('Error en getFormasPago: $e');
      return [];
    }
  }

  // Insertar un nuevo pago de cuentas por cobrar - VERSIÓN MEJORADA
  Future<Map<String, dynamic>> insertarPago(PagosCuentasXCobrar pago) async {
    try {
      final url = Uri.parse('$_apiServer/PagosCuentasPorCobrar/Insertar');
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey,
      };

      // Usar directamente el método toJson() del objeto
      final body = jsonEncode(pago.toJson());



      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      // Analizar respuesta según status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decoded = jsonDecode(response.body);
          
          if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('data')) {
              return {
                'success': true,
                'data': decoded['data'],
                'message': 'Pago insertado correctamente'
              };
            } else {
              return {
                'success': true,
                'data': decoded,
                'message': 'Pago insertado correctamente'
              };
            }
          } else {
            return {
              'success': true,
              'data': decoded,
              'message': 'Pago insertado correctamente'
            };
          }
        } catch (jsonError) {
          developer.log('Error parsing JSON exitoso: $jsonError');
          return {
            'success': true,
            'data': response.body,
            'message': 'Pago insertado correctamente'
          };
        }
      } else {
        // Manejar diferentes tipos de errores HTTP
        String errorMessage = 'Error HTTP ${response.statusCode}';
        
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage += ' - ${errorBody['message'] ?? errorBody['error'] ?? 'Error desconocido'}';
            
            // Si hay detalles adicionales de validación
            if (errorBody.containsKey('errors')) {
              errorMessage += '\nDetalles: ${errorBody['errors']}';
            }
          }
        } catch (e) {
          errorMessage += ' - Response: ${response.body}';
        }
        
        developer.log('Error en respuesta: $errorMessage');
        
        return {
          'success': false,
          'data': null,
          'message': errorMessage
        };
      }
    } catch (e) {
      developer.log('Excepción en insertarPago: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Error de conexión: $e'
      };
    }
  }

  // Método auxiliar para validar los datos antes de enviar - MEJORADO
  bool validarDatosPago(PagosCuentasXCobrar pago) {
    developer.log('🔍 INICIANDO VALIDACIÓN DEL PAGO');
    
    // Validar cpCoId
    if (pago.cpCoId <= 0) {
      developer.log('❌ Error validación: cpCoId debe ser mayor a 0. Valor actual: ${pago.cpCoId}');
      return false;
    }
    developer.log('✅ cpCoId válido: ${pago.cpCoId}');
    
    // Validar pagoMonto
    if (pago.pagoMonto <= 0) {
      developer.log('❌ Error validación: pagoMonto debe ser mayor a 0. Valor actual: ${pago.pagoMonto}');
      return false;
    }
    developer.log('✅ pagoMonto válido: ${pago.pagoMonto}');
    
    // Validar foPaId
    if (pago.foPaId <= 0) {
      developer.log('❌ Error validación: foPaId debe ser mayor a 0. Valor actual: ${pago.foPaId}');
      return false;
    }
    developer.log('✅ foPaId válido: ${pago.foPaId}');
    
    // Validar pagoNumeroReferencia
    if (pago.pagoNumeroReferencia.trim().isEmpty) {
      developer.log('❌ Error validación: pagoNumeroReferencia no puede estar vacío. Valor actual: "${pago.pagoNumeroReferencia}"');
      return false;
    }
    developer.log('✅ pagoNumeroReferencia válido: "${pago.pagoNumeroReferencia}"');
    
    // Validar pagoObservaciones
    if (pago.pagoObservaciones.trim().isEmpty) {
      developer.log('❌ Error validación: pagoObservaciones no puede estar vacío. Valor actual: "${pago.pagoObservaciones}"');
      return false;
    }
    developer.log('✅ pagoObservaciones válido: "${pago.pagoObservaciones}"');
    
    // Validar usuaCreacion
    if (pago.usuaCreacion <= 0) {
      developer.log('Error validación: usuaCreacion debe ser mayor a 0. Valor actual: ${pago.usuaCreacion}');
      return false;
    }

    
    return true;
  }
  
  // MÉTODO ADICIONAL: Verificar que la cuenta por cobrar existe y está activa
  Future<bool> verificarCuentaPorCobrar(int cpCoId) async {
    try {
      final url = Uri.parse('$_apiServer/CuentasPorCobrar/Detalle/$cpCoId');
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey,
      };

      final response = await http.get(url, headers: headers);
      
      developer.log('🔍 Verificando cuenta $cpCoId - Status: ${response.statusCode}');
      
      return response.statusCode == 200;
    } catch (e) {
      developer.log('Error verificando cuenta: $e');
      return false;
    }
  }

Future<List<PagosCuentasXCobrar>> listarPagosPorCuenta(int cpCoId) async {
  try {
    final url = Uri.parse('$_apiServer/PagosCuentasPorCobrar/ListarPorCuentaPorCobrar/$cpCoId');
    
    final headers = {
      'Content-Type': 'application/json',
      'X-Api-Key': _apiKey,
    };

    developer.log('💰 Obteniendo pagos para cuenta: $cpCoId - URL: $url');

    final response = await http.get(url, headers: headers);

    developer.log('💰 Response status: ${response.statusCode}');
    developer.log('💰 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) {
          developer.log('✅ Pagos encontrados: ${data.length}');
          return data.map((item) => PagosCuentasXCobrar.fromJson(item)).toList();
        } else {
          developer.log('⚠️ La clave "data" no es una lista');
          return [];
        }
      } 
      else if (decoded is List) {
        developer.log('✅ Pagos encontrados (lista directa): ${decoded.length}');
        return decoded.map((item) => PagosCuentasXCobrar.fromJson(item)).toList();
      } else {
        developer.log('⚠️ Respuesta inesperada del servidor');
        return [];
      }
    } else if (response.statusCode == 404) {
      // No hay pagos registrados para esta cuenta
      developer.log('📭 No hay pagos registrados para la cuenta $cpCoId');
      return [];
    } else {
      developer.log('❌ Error al obtener pagos: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    developer.log('❌ Error en listarPagosPorCuenta: $e');
    return [];
  }
}


}