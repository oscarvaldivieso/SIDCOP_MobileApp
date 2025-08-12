import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/models/ventas/VentaInsertarViewModel.dart';

class VentaService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  /// Inserta una nueva factura/venta en el sistema
  /// Recibe un [VentaInsertarViewModel] con todos los datos de la venta
  /// Retorna un Map con la respuesta del servidor o información de error
  Future<Map<String, dynamic>?> insertarFactura(
    VentaInsertarViewModel venta,
  ) async {
    final url = Uri.parse('$_apiServer/Facturas/Insertar');

    developer.log('Insertar Factura Request URL: $url');

    try {
      // Convertir el modelo a JSON
      final body = venta.toJson();
      
      developer.log('Insertar Factura Request Body: ${jsonEncode(body)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
        body: jsonEncode(body),
      );

      developer.log('Insertar Factura Response Status: ${response.statusCode}');
      developer.log('Insertar Factura Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'message': 'Factura insertada exitosamente',
        };
      } else {
        developer.log('Error al insertar factura: ${response.statusCode}');
        return {
          'success': false,
          'error': true,
          'message': 'Error al insertar factura: ${response.statusCode}',
          'details': response.body,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      developer.log('Insertar Factura Error: $e');
      return {
        'success': false,
        'error': true,
        'message': 'Error de conexión: $e',
        'exception': e.toString(),
      };
    }
  }

  /// Método auxiliar para validar los datos de la venta antes de enviar
  bool validarVenta(VentaInsertarViewModel venta) {
    // Validaciones básicas
    if (venta.clieId <= 0) {
      developer.log('Error: Cliente ID no válido');
      return false;
    }
    
    if (venta.vendId <= 0) {
      developer.log('Error: Vendedor ID no válido');
      return false;
    }
    
    if (venta.detallesFacturaInput.isEmpty) {
      developer.log('Error: No hay productos en la factura');
      return false;
    }
    
    // Validar que todos los productos tengan cantidad mayor a 0
    for (var detalle in venta.detallesFacturaInput) {
      if (detalle.faDeCantidad <= 0) {
        developer.log('Error: Producto con cantidad inválida: ${detalle.prodId}');
        return false;
      }
    }
    
    return true;
  }

  /// Método para insertar factura con validación previa
  Future<Map<String, dynamic>?> insertarFacturaConValidacion(
    VentaInsertarViewModel venta,
  ) async {
    // Validar datos antes de enviar
    if (!validarVenta(venta)) {
      return {
        'success': false,
        'error': true,
        'message': 'Datos de venta no válidos',
        'validation': false,
      };
    }

    // Si la validación pasa, proceder con la inserción
    return await insertarFactura(venta);
  }
}