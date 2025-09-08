import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'GlobalService.dart';
import 'OfflineDatabaseService.dart';

class InventoryService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;

  /// Verifica si hay conexión a internet
  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking internet connection: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getInventoryByVendor(int vendorId) async {
    // Verificar conexión a internet
    final hasConnection = await _hasInternetConnection();
    
    if (hasConnection) {
      // Modo online: obtener datos del servidor
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
          final inventoryData = List<Map<String, dynamic>>.from(jsonData);
          
          // Guardar datos en caché offline
          try {
            final saved = await OfflineDatabaseService.saveInventoryData(inventoryData);
            if (saved) {
              debugPrint('✅ Inventario guardado en caché offline: ${inventoryData.length} productos');
            } else {
              debugPrint('❌ Error al guardar inventario en caché offline');
            }
          } catch (e) {
            debugPrint('❌ Excepción al guardar inventario offline: $e');
          }
          
          return inventoryData;
        } else {
          throw Exception('Failed to load inventory: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching inventory online: $e');
        // Solo hacer fallback a offline si realmente hay datos offline disponibles
        final hasOfflineData = await hasOfflineInventoryData();
        if (hasOfflineData) {
          debugPrint('Fallback to offline data');
          return await _getOfflineInventoryData();
        } else {
          // Si no hay datos offline, relanzar el error original
          debugPrint('No offline data available, rethrowing original error');
          rethrow;
        }
      }
    } else {
      // Modo offline: usar datos en caché
      debugPrint('Sin conexión, usando datos offline de inventario');
      return await _getOfflineInventoryData();
    }
  }

  /// Obtiene datos de inventario desde el almacenamiento offline
  Future<List<Map<String, dynamic>>> _getOfflineInventoryData() async {
    try {
      debugPrint('🔍 Intentando cargar datos de inventario offline...');
      final offlineData = await OfflineDatabaseService.loadInventoryData();
      debugPrint('📦 Datos offline obtenidos: ${offlineData.length} registros');
      
      if (offlineData.isNotEmpty) {
        debugPrint('✅ Inventario cargado desde offline: ${offlineData.length} productos');
        return offlineData;
      } else {
        debugPrint('⚠️ No hay datos de inventario offline disponibles');
        throw Exception('No hay datos de inventario disponibles offline. Conecta a internet para sincronizar.');
      }
    } catch (e) {
      debugPrint('❌ Error loading offline inventory data: $e');
      throw Exception('Error al cargar datos offline de inventario: $e');
    }
  }

  // Nuevo método para obtener jornada detallada con soporte offline
  Future<Map<String, dynamic>> getJornadaDetallada(int vendorId) async {
    final hasConnection = await _hasInternetConnection();
    
    if (hasConnection) {
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
            final jornadaData = jsonData['data'] as Map<String, dynamic>;
            
            // Guardar en caché offline
            await OfflineDatabaseService.saveJornadaDetalladaData(jornadaData);
            debugPrint('Jornada detallada guardada en caché offline');
            
            return jornadaData;
          } else {
            throw Exception('API returned unsuccessful response: ${jsonData['message'] ?? 'Unknown error'}');
          }
        } else {
          throw Exception('Failed to load jornada detallada: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching jornada detallada online, fallback to offline: $e');
        return await _getOfflineJornadaDetallada();
      }
    } else {
      debugPrint('Sin conexión, usando datos offline de jornada detallada');
      return await _getOfflineJornadaDetallada();
    }
  }

  /// Obtiene jornada detallada desde el almacenamiento offline
  Future<Map<String, dynamic>> _getOfflineJornadaDetallada() async {
    try {
      final offlineData = await OfflineDatabaseService.loadJornadaDetalladaData();
      if (offlineData != null) {
        debugPrint('Jornada detallada cargada desde offline');
        return offlineData;
      } else {
        throw Exception('No hay datos de jornada detallada disponibles offline. Conecta a internet para sincronizar.');
      }
    } catch (e) {
      debugPrint('Error loading offline jornada detallada: $e');
      throw Exception('Error al cargar datos offline de jornada detallada: $e');
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
    final hasConnection = await _hasInternetConnection();
    
    if (hasConnection) {
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
            // Guardar en caché offline
            await OfflineDatabaseService.saveJornadaActivaData(responseData);
            debugPrint('Jornada activa guardada en caché offline');
            
            return responseData; // Returns full response including data, code, success, and message
          }
          throw Exception(responseData['message'] ?? 'Error desconocido al obtener la jornada activa');
        } else {
          throw Exception('Error al obtener la jornada activa: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error en getJornadaActiva online, fallback to offline: $e');
        return await _getOfflineJornadaActiva();
      }
    } else {
      debugPrint('Sin conexión, usando datos offline de jornada activa');
      return await _getOfflineJornadaActiva();
    }
  }

  /// Obtiene jornada activa desde el almacenamiento offline
  Future<Map<String, dynamic>> _getOfflineJornadaActiva() async {
    try {
      final offlineData = await OfflineDatabaseService.loadJornadaActivaData();
      if (offlineData != null) {
        debugPrint('Jornada activa cargada desde offline');
        return offlineData;
      } else {
        // Retornar estructura por defecto cuando no hay datos offline
        return {
          'success': false,
          'data': null,
          'message': 'No hay datos de jornada activa disponibles offline',
          'code': 'OFFLINE_NO_DATA'
        };
      }
    } catch (e) {
      debugPrint('Error loading offline jornada activa: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Error al cargar datos offline de jornada activa: $e',
        'code': 'OFFLINE_ERROR'
      };
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

  /// Sincroniza datos de inventario cuando hay conexión
  Future<bool> syncInventoryData(int vendorId) async {
    try {
      final hasConnection = await _hasInternetConnection();
      if (!hasConnection) {
        debugPrint('No hay conexión para sincronizar inventario');
        return false;
      }

      // Sincronizar inventario
      await getInventoryByVendor(vendorId);
      
      // Sincronizar jornada activa
      await getJornadaActiva(vendorId);
      
      debugPrint('Sincronización de inventario completada exitosamente');
      return true;
    } catch (e) {
      debugPrint('Error durante la sincronización de inventario: $e');
      return false;
    }
  }

  /// Verifica si hay datos offline disponibles
  Future<bool> hasOfflineInventoryData() async {
    try {
      final inventoryData = await OfflineDatabaseService.loadInventoryData();
      debugPrint('🔍 Verificando datos offline: ${inventoryData.length} productos encontrados');
      return inventoryData.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking offline inventory data: $e');
      return false;
    }
  }

  /// Fuerza la carga de datos offline (para debugging y testing)
  Future<List<Map<String, dynamic>>> forceOfflineInventoryLoad() async {
    debugPrint('🔧 Forzando carga de datos offline...');
    return await _getOfflineInventoryData();
  }
}
