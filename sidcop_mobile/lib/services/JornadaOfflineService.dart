import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'inventory_service.dart';

class JornadaOfflineService {
  static const String _fileName = 'jornada_pendientes.json';
  static const String _jornadaStateFileName = 'jornada_estado_offline.json';
  
  /// Guarda una operación de jornada offline (iniciar o cerrar)
  static Future<bool> guardarOperacionJornadaOffline({
    required String tipoOperacion, // 'iniciar' o 'cerrar'
    required int vendorId,
    required int usuaCreacion,
    Map<String, dynamic>? datosAdicionales,
  }) async {
    try {
      debugPrint('💾 Guardando operación de jornada offline: $tipoOperacion');
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      List<Map<String, dynamic>> operacionesPendientes = [];
      
      // Cargar operaciones existentes
      if (await file.exists()) {
        final contenido = await file.readAsString();
        if (contenido.isNotEmpty) {
          final List<dynamic> jsonData = json.decode(contenido);
          operacionesPendientes = List<Map<String, dynamic>>.from(jsonData);
        }
      }
      
      // Crear nueva operación
      final nuevaOperacion = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'tipoOperacion': tipoOperacion,
        'vendorId': vendorId,
        'usuaCreacion': usuaCreacion,
        'fechaCreacion': DateTime.now().toIso8601String(),
        'intentos': 0,
        'datosAdicionales': datosAdicionales ?? {},
      };
      
      // Evitar duplicados de la misma operación
      operacionesPendientes.removeWhere((op) => 
        op['tipoOperacion'] == tipoOperacion && 
        op['vendorId'] == vendorId
      );
      
      operacionesPendientes.add(nuevaOperacion);
      
      // Guardar archivo
      await file.writeAsString(json.encode(operacionesPendientes));
      
      // Si es iniciar jornada, actualizar estado local
      if (tipoOperacion == 'iniciar') {
        await _actualizarEstadoJornadaLocal(vendorId, true, nuevaOperacion);
      } else if (tipoOperacion == 'cerrar') {
        await _actualizarEstadoJornadaLocal(vendorId, false, datosAdicionales);
      }
      
      debugPrint('✅ Operación de jornada guardada offline: $tipoOperacion');
      return true;
    } catch (e) {
      debugPrint('❌ Error al guardar operación de jornada offline: $e');
      return false;
    }
  }
  
  /// Actualiza el estado local de la jornada
  static Future<void> _actualizarEstadoJornadaLocal(
    int vendorId, 
    bool activa, 
    Map<String, dynamic>? datos
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_jornadaStateFileName');
      
      final estadoJornada = {
        'vendorId': vendorId,
        'activa': activa,
        'fechaActualizacion': DateTime.now().toIso8601String(),
        'datos': datos ?? {},
        'esOffline': true,
      };
      
      await file.writeAsString(json.encode(estadoJornada));
      debugPrint('📱 Estado local de jornada actualizado: ${activa ? "ACTIVA" : "CERRADA"}');
    } catch (e) {
      debugPrint('❌ Error al actualizar estado local de jornada: $e');
    }
  }
  
  /// Obtiene el estado local de la jornada
  static Future<Map<String, dynamic>?> obtenerEstadoJornadaLocal(int vendorId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_jornadaStateFileName');
      
      if (await file.exists()) {
        final contenido = await file.readAsString();
        if (contenido.isNotEmpty) {
          final Map<String, dynamic> estado = json.decode(contenido);
          if (estado['vendorId'] == vendorId) {
            return estado;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error al obtener estado local de jornada: $e');
      return null;
    }
  }
  
  /// Sincroniza operaciones pendientes con el servidor
  static Future<bool> sincronizarOperacionesPendientes() async {
    try {
      debugPrint('🔄 Iniciando sincronización de operaciones de jornada pendientes...');
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (!await file.exists()) {
        debugPrint('📝 No hay operaciones de jornada pendientes para sincronizar');
        return true;
      }
      
      final contenido = await file.readAsString();
      if (contenido.isEmpty) {
        debugPrint('📝 Archivo de operaciones de jornada pendientes está vacío');
        return true;
      }
      
      final List<dynamic> jsonData = json.decode(contenido);
      final List<Map<String, dynamic>> operacionesPendientes = 
          List<Map<String, dynamic>>.from(jsonData);
      
      if (operacionesPendientes.isEmpty) {
        debugPrint('📝 No hay operaciones de jornada pendientes para sincronizar');
        return true;
      }
      
      final inventoryService = InventoryService();
      List<Map<String, dynamic>> operacionesFallidas = [];
      int operacionesExitosas = 0;
      
      for (final operacion in operacionesPendientes) {
        try {
          debugPrint('🔄 Sincronizando operación: ${operacion['tipoOperacion']}');
          
          bool exito = false;
          
          if (operacion['tipoOperacion'] == 'iniciar') {
            final resultado = await inventoryService.startJornada(
              operacion['vendorId'], 
              operacion['usuaCreacion']
            );
            exito = resultado != null;
          } else if (operacion['tipoOperacion'] == 'cerrar') {
            final resultado = await inventoryService.closeJornada(
              operacion['vendorId']
            );
            exito = resultado != null;
          }
          
          if (exito) {
            debugPrint('✅ Operación sincronizada: ${operacion['tipoOperacion']}');
            operacionesExitosas++;
          } else {
            debugPrint('❌ Falló sincronización: ${operacion['tipoOperacion']}');
            operacion['intentos'] = (operacion['intentos'] ?? 0) + 1;
            operacion['ultimoIntento'] = DateTime.now().toIso8601String();
            operacionesFallidas.add(operacion);
          }
        } catch (e) {
          debugPrint('❌ Error al sincronizar operación ${operacion['tipoOperacion']}: $e');
          operacion['intentos'] = (operacion['intentos'] ?? 0) + 1;
          operacion['ultimoIntento'] = DateTime.now().toIso8601String();
          operacion['ultimoError'] = e.toString();
          operacionesFallidas.add(operacion);
        }
      }
      
      // Actualizar archivo con operaciones fallidas
      if (operacionesFallidas.isEmpty) {
        await file.delete();
        debugPrint('🗑️ Archivo de operaciones pendientes eliminado - todas sincronizadas');
      } else {
        await file.writeAsString(json.encode(operacionesFallidas));
        debugPrint('📝 ${operacionesFallidas.length} operaciones permanecen pendientes');
      }
      
      debugPrint('📊 Sincronización completada: $operacionesExitosas exitosas, ${operacionesFallidas.length} fallidas');
      return operacionesFallidas.isEmpty;
      
    } catch (e) {
      debugPrint('❌ Error durante sincronización de operaciones de jornada: $e');
      return false;
    }
  }
  
  /// Verifica si hay operaciones pendientes
  static Future<bool> hayOperacionesPendientes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (!await file.exists()) return false;
      
      final contenido = await file.readAsString();
      if (contenido.isEmpty) return false;
      
      final List<dynamic> jsonData = json.decode(contenido);
      return jsonData.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error al verificar operaciones pendientes: $e');
      return false;
    }
  }
  
  /// Cuenta las operaciones pendientes
  static Future<int> contarOperacionesPendientes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (!await file.exists()) return 0;
      
      final contenido = await file.readAsString();
      if (contenido.isEmpty) return 0;
      
      final List<dynamic> jsonData = json.decode(contenido);
      return jsonData.length;
    } catch (e) {
      debugPrint('❌ Error al contar operaciones pendientes: $e');
      return 0;
    }
  }
  
  /// Obtiene información de operaciones pendientes
  static Future<Map<String, dynamic>> obtenerInfoOperacionesPendientes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (!await file.exists()) {
        return {'total': 0, 'operaciones': []};
      }
      
      final contenido = await file.readAsString();
      if (contenido.isEmpty) {
        return {'total': 0, 'operaciones': []};
      }
      
      final List<dynamic> jsonData = json.decode(contenido);
      final operaciones = List<Map<String, dynamic>>.from(jsonData);
      
      return {
        'total': operaciones.length,
        'operaciones': operaciones,
        'iniciar': operaciones.where((op) => op['tipoOperacion'] == 'iniciar').length,
        'cerrar': operaciones.where((op) => op['tipoOperacion'] == 'cerrar').length,
      };
    } catch (e) {
      debugPrint('❌ Error al obtener info de operaciones pendientes: $e');
      return {'total': 0, 'operaciones': [], 'error': e.toString()};
    }
  }
  
  
  /// Limpia todas las operaciones pendientes (para casos de emergencia)
  static Future<bool> limpiarOperacionesPendientes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      final stateFile = File('${directory.path}/$_jornadaStateFileName');
      
      if (await file.exists()) {
        await file.delete();
      }
      
      if (await stateFile.exists()) {
        await stateFile.delete();
      }
      
      debugPrint('🗑️ Operaciones de jornada pendientes limpiadas');
      return true;
    } catch (e) {
      debugPrint('❌ Error al limpiar operaciones pendientes: $e');
      return false;
    }
  }
}
