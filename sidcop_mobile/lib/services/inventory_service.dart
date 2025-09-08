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
    // Primero verificar si hay datos offline disponibles
    final hasOfflineData = await hasOfflineInventoryData();
    final hasConnection = await _hasInternetConnection();
    
    // Si tenemos conexión, intentar actualizar datos online
    if (hasConnection) {
      debugPrint('🌐 Conexión disponible, actualizando inventario desde servidor...');
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
          
          // SIEMPRE guardar datos actualizados en caché offline para uso futuro
          try {
            final saved = await OfflineDatabaseService.saveInventoryData(inventoryData);
            if (saved) {
              debugPrint('✅ Inventario actualizado y guardado offline: ${inventoryData.length} productos');
            } else {
              debugPrint('❌ Error al guardar inventario actualizado offline');
            }
          } catch (e) {
            debugPrint('❌ Excepción al guardar inventario offline: $e');
          }
          
          return inventoryData;
        } else {
          throw Exception('Failed to load inventory: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Error al obtener inventario online: $e');
        // Si hay datos offline, usarlos como fallback
        if (hasOfflineData) {
          debugPrint('📦 Usando datos offline como fallback');
          return await _getOfflineInventoryData();
        } else {
          // Si no hay datos offline, mostrar error específico
          throw Exception('No se pudo conectar al servidor y no hay datos offline disponibles. Conecta a internet para sincronizar por primera vez.');
        }
      }
    } else {
      // Sin conexión: usar datos offline si están disponibles
      if (hasOfflineData) {
        debugPrint('📱 Sin conexión, usando inventario offline');
        return await _getOfflineInventoryData();
      } else {
        // Sin conexión y sin datos offline
        throw Exception('Sin conexión a internet y no hay datos offline disponibles. Conecta a internet para sincronizar por primera vez.');
      }
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

  // Método para obtener jornada detallada con soporte offline persistente
  Future<Map<String, dynamic>> getJornadaDetallada(int vendorId) async {
    final hasOfflineData = await _hasOfflineJornadaDetalladaData();
    final hasConnection = await _hasInternetConnection();
    
    if (hasConnection) {
      debugPrint('🌐 Actualizando jornada detallada desde servidor...');
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
          final Map<String, dynamic> jornadaData = json.decode(response.body);
          
          // SIEMPRE guardar datos actualizados para uso offline futuro
          await OfflineDatabaseService.saveJornadaDetalladaData(jornadaData);
          debugPrint('✅ Jornada detallada actualizada y guardada offline');
          
          return jornadaData;
        } else {
          throw Exception('Failed to load jornada detallada: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Error al obtener jornada detallada online: $e');
        if (hasOfflineData) {
          debugPrint('📦 Usando jornada detallada offline como fallback');
          final offlineData = await OfflineDatabaseService.loadJornadaDetalladaData();
          return offlineData!;
        } else {
          throw Exception('No se pudo conectar al servidor y no hay datos offline de jornada detallada. Conecta a internet para sincronizar por primera vez.');
        }
      }
    } else {
      // Sin conexión: usar datos offline si están disponibles
      if (hasOfflineData) {
        debugPrint('📱 Sin conexión, usando jornada detallada offline');
        final offlineData = await OfflineDatabaseService.loadJornadaDetalladaData();
        return offlineData!;
      } else {
        throw Exception('Sin conexión a internet y no hay datos offline de jornada detallada. Conecta a internet para sincronizar por primera vez.');
      }
    }
  }

  /// Verifica si hay datos offline de jornada detallada
  Future<bool> _hasOfflineJornadaDetalladaData() async {
    try {
      final data = await OfflineDatabaseService.loadJornadaDetalladaData();
      return data != null;
    } catch (e) {
      return false;
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
