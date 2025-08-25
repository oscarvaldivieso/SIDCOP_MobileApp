import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'GlobalService.dart';

class InventoryService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  Future<List<Map<String, dynamic>>> getInventoryByVendor(int vendorId) async {
    final url = Uri.parse('$_apiServer/InventarioBodegas/InventarioAsignado?Vend_Id=$vendorId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(jsonData);
      } else {
        throw Exception('Failed to load inventory: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      rethrow;
    }
  }

  // Nuevo método para obtener jornada detallada
  Future<Map<String, dynamic>> getJornadaDetallada(int vendorId) async {
    final url = Uri.parse('$_apiServer/InventarioBodegas/JornadaDetallada/$vendorId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        // Verificar que la respuesta sea exitosa
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return jsonData['data'] as Map<String, dynamic>;
        } else {
          throw Exception('API returned unsuccessful response: ${jsonData['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load jornada detallada: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching jornada detallada: $e');
      rethrow;
    }
  }


    Future<Map<String, dynamic>?> closeJornada(int vendorId) async {
    final url = Uri.parse('$_apiServer/InventarioBodegas/CierreJornada?Vend_Id=$vendorId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        if (jsonData.isNotEmpty) {
          return jsonData.first as Map<String, dynamic>;
        }
        return null;
      } else {
        throw Exception('Failed to close jornada: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error closing jornada: $e');
      rethrow;
    }
  }
}
