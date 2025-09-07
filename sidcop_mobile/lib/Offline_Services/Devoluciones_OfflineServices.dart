import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';

/// Servicio offline para operaciones relacionadas con devoluciones.
class DevolucionesOffline {
  // Nombres de archivos para almacenar datos
  static const String _archivoDevolucionesHistorial = "devoluciones_historial.json";
  
  // Instancia de secure storage para almacenar datos
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo`.
  /// Escritura atómica: se guarda el JSON como string en secure storage bajo la clave "json:<nombreArchivo>".
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      final key = "json:$nombreArchivo";
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      print("Error al guardar JSON $nombreArchivo: $e");
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = "json:$nombreArchivo";
      final s = await _secureStorage.read(key: key);
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      print("Error al leer JSON $nombreArchivo: $e");
      rethrow;
    }
  }

  /// Sincroniza las devoluciones con el servidor y guarda el resultado localmente
  static Future<List<Map<String, dynamic>>> sincronizarDevoluciones() async {
    try {
      print("Sincronizando devoluciones desde el servidor...");
      final service = DevolucionesService();
      final devoluciones = await service.listarDevoluciones();
      
      // Convertir a formato Map para almacenamiento
      final List<Map<String, dynamic>> devolucionesMap = 
          devoluciones.map((dev) => dev.toJson()).toList();
      
      print("Se sincronizaron ${devolucionesMap.length} devoluciones");
      return devolucionesMap;
    } catch (e) {
      print("Error al sincronizar devoluciones: $e");
      // Si ocurre un error, devolver una lista vacía
      return [];
    }
  }

  /// Guarda devoluciones en almacenamiento local
  static Future<void> guardarDevolucionesHistorial(List<Map<String, dynamic>> devoluciones) async {
    try {
      print("Guardando ${devoluciones.length} devoluciones en almacenamiento local");
      await guardarJson(_archivoDevolucionesHistorial, devoluciones);
      print("Devoluciones guardadas exitosamente");
    } catch (e) {
      print("Error al guardar devoluciones: $e");
      rethrow;
    }
  }

  /// Obtiene las devoluciones guardadas localmente
  static Future<List<Map<String, dynamic>>> obtenerDevolucionesLocal() async {
    try {
      print("Obteniendo devoluciones del almacenamiento local");
      final data = await leerJson(_archivoDevolucionesHistorial);
      
      if (data == null) {
        print("No se encontraron devoluciones guardadas localmente");
        return [];
      }
      
      final List<Map<String, dynamic>> devoluciones = 
          List<Map<String, dynamic>>.from(data as List);
          
      print("Se encontraron ${devoluciones.length} devoluciones locales");
      return devoluciones;
    } catch (e) {
      print("Error al obtener devoluciones locales: $e");
      return [];
    }
  }

  /// Sincroniza y guarda todas las devoluciones
  static Future<List<Map<String, dynamic>>> sincronizarYGuardarDevoluciones() async {
    try {
      final devoluciones = await sincronizarDevoluciones();
      await guardarDevolucionesHistorial(devoluciones);
      return devoluciones;
    } catch (e) {
      print("Error al sincronizar y guardar devoluciones: $e");
      // Intentar devolver lo que esté guardado localmente
      return await obtenerDevolucionesLocal();
    }
  }

  /// Convierte una lista de Maps a una lista de DevolucionesViewModel
  static List<DevolucionesViewModel> convertirAModelos(List<Map<String, dynamic>> devoluciones) {
    try {
      return devoluciones.map((dev) => DevolucionesViewModel.fromJson(dev)).toList();
    } catch (e) {
      print("Error al convertir devoluciones a modelos: $e");
      return [];
    }
  }
}
