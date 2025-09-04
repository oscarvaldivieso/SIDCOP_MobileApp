import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.Dart';

class FacturaService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<dynamic>> getFacturas() async {
    final url = Uri.parse('$_apiServer/Facturas/Listar');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'X-Api-Key': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List;
        }
        throw Exception(data['message'] ?? 'Error al cargar facturas');
      } else {
        throw Exception('Error al cargar facturas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

    Future<List<dynamic>> getFacturasDevolucionesLimite() async {
    final url = Uri.parse('$_apiServer/Facturas/ListarConLimiteDevolucion');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'X-Api-Key': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as List;
        }
        throw Exception(data['message'] ?? 'Error al cargar facturas');
      } else {
        throw Exception('Error al cargar facturas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  Future<Map<String, dynamic>> insertarFactura(Map<String, dynamic> facturaData) async {
    final url = Uri.parse('$_apiServer/Facturas/Insertar');
    
    try {
      print('ENVIANDO PETICIÓN A: $url');
      
      final response = await http.post(
        url,
        headers: {
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(facturaData),
      );

      print('CÓDIGO DE RESPUESTA: ${response.statusCode}');
      print('CUERPO DE RESPUESTA: ${response.body}');
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        print('INSERCIÓN EXITOSA: ${data['message']}');
        return data;
      } else {
        print('ERROR EN LA RESPUESTA: ${data['message'] ?? 'Sin mensaje de error'}');
        print('DETALLES DEL ERROR: ${data['errors'] ?? 'Sin detalles adicionales'}');
        throw Exception(data['message'] ?? 'Error al insertar factura: ${response.statusCode}');
      }
    } catch (e) {
      print('EXCEPCIÓN AL INSERTAR FACTURA: $e');
      throw Exception('Error al conectar con el servidor: $e');
    }
  }
}

