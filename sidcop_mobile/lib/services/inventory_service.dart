import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity.dart';
import 'GlobalService.dart';
import 'local_database/inventory_local_service.dart';

class InventoryService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  final InventoryLocalService _localService = InventoryLocalService();

  Future<List<Map<String, dynamic>>> getInventoryByVendor(int vendorId) async {
    try {
      // Check internet connection
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      
      if (hasConnection) {
        // If online, fetch from API and update local storage
        final url = Uri.parse('$_apiServer/InventarioBodegas/InventarioAsignado?Vend_Id=$vendorId');
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
          final inventory = List<Map<String, dynamic>>.from(jsonData);
          
          // Save to local database for offline access
          await _localService.saveInventory(inventory, vendorId);
          
          return inventory;
        } else {
          // If API fails but we have local data, return that
          final localData = await _localService.getInventory(vendorId);
          if (localData.isNotEmpty) {
            return localData;
          }
          throw Exception('Failed to load inventory: ${response.statusCode}');
        }
      } else {
        // If offline, return local data
        debugPrint('No internet connection, loading from local storage');
        final localData = await _localService.getInventory(vendorId);
        if (localData.isNotEmpty) {
          return localData;
        }
        throw Exception('No internet connection and no local data available');
      }
    } catch (e) {
      debugPrint('Error in getInventoryByVendor: $e');
      // Try to return local data even if there was an error
      try {
        final localData = await _localService.getInventory(vendorId);
        if (localData.isNotEmpty) {
          return localData;
        }
      } catch (localError) {
        debugPrint('Error loading local inventory: $localError');
      }
      rethrow;
    }
  }

  // Método para sincronizar el inventario (llamar durante el login)
  Future<void> syncInventory(int vendorId) async {
    try {
      final url = Uri.parse('$_apiServer/InventarioBodegas/InventarioAsignado?Vend_Id=$vendorId');
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
        await _localService.saveInventory(
          List<Map<String, dynamic>>.from(jsonData),
          vendorId,
        );
        debugPrint('Inventory synced successfully for vendor $vendorId');
      } else {
        debugPrint('Failed to sync inventory: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing inventory: $e');
    }
  }

  // Método para obtener jornada detallada
  Future<Map<String, dynamic>> getJornadaDetallada(int vendorId) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      
      if (hasConnection) {
        final url = Uri.parse('$_apiServer/InventarioBodegas/JornadaDetallada/$vendorId');
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
          return jsonData;
        }
      }
      
      // Si estamos offline o hay un error, devolver datos básicos
      return {
        'success': true,
        'message': 'Datos en modo offline',
        'data': {
          'inventario': await _localService.getInventory(vendorId),
        },
      };
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


    Future<Map<String, dynamic>?> startJornada(int vendorId, int usuaCreacion) async {
    final url = Uri.parse('$_apiServer/InventarioBodegas/IniciarJornada?Vend_Id=$vendorId&Usuario_Creacion=$usuaCreacion');
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
          return jsonData[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error starting jornada: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getJornadaActiva(int vendorId) async {
    final url = Uri.parse('$_apiServer/InventarioBodegas/JornadaActiva?Vend_Id=$vendorId');
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
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData; // Returns full response including data, code, success, and message
        }
        throw Exception(responseData['message'] ?? 'Error desconocido al obtener la jornada activa');
      } else {
        throw Exception('Error al obtener la jornada activa: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en getJornadaActiva: $e');
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
