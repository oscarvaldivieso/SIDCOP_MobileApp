import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';

/// Servicio offline para operaciones relacionadas con devoluciones.
class DevolucionesOffline {
  // Nombres de archivos para almacenar datos
  static const String _archivoDevolucionesHistorial =
      "devoluciones_historial.json";
  static const String _archivoDetallesDevolucion = "devoluciones_detalles.json";

  // Instancia de secure storage para almacenar datos
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo`.
  /// Escritura at�mica: se guarda el JSON como string en secure storage bajo la clave "json:<nombreArchivo>".
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
      final List<Map<String, dynamic>> devolucionesMap = devoluciones
          .map((dev) => dev.toJson())
          .toList();

      print("Se sincronizaron ${devolucionesMap.length} devoluciones");
      return devolucionesMap;
    } catch (e) {
      print("Error al sincronizar devoluciones: $e");
      // Si ocurre un error, devolver una lista vac�a
      return [];
    }
  }

  /// Guarda devoluciones en almacenamiento local
  static Future<void> guardarDevolucionesHistorial(
    List<Map<String, dynamic>> devoluciones,
  ) async {
    try {
      print(
        "Guardando ${devoluciones.length} devoluciones en almacenamiento local",
      );
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
  static Future<List<Map<String, dynamic>>>
  sincronizarYGuardarDevoluciones() async {
    try {
      final devoluciones = await sincronizarDevoluciones();
      await guardarDevolucionesHistorial(devoluciones);
      return devoluciones;
    } catch (e) {
      print("Error al sincronizar y guardar devoluciones: $e");
      // Intentar devolver lo que est� guardado localmente
      return await obtenerDevolucionesLocal();
    }
  }

  /// Convierte una lista de Maps a una lista de DevolucionesViewModel
  static List<DevolucionesViewModel> convertirAModelos(
    List<Map<String, dynamic>> devoluciones,
  ) {
    try {
      return devoluciones
          .map((dev) => DevolucionesViewModel.fromJson(dev))
          .toList();
    } catch (e) {
      print("Error al convertir devoluciones a modelos: $e");
      return [];
    }
  }

  /// Sincroniza y guarda los detalles de una devolución específica
  static Future<List<Map<String, dynamic>>>
  sincronizarYGuardarDetallesDevolucion(int devolucionId) async {
    try {
      print("Sincronizando detalles de devolución ID: $devolucionId");
      final detalles = await sincronizarDetallesDevolucion(devolucionId);
      await guardarDetallesDevolucion(devolucionId, detalles);
      return detalles;
    } catch (e) {
      print(
        "Error al sincronizar y guardar detalles de devolución ID $devolucionId: $e",
      );
      // Intentar devolver lo que está guardado localmente
      return await obtenerDetallesDevolucionLocal(devolucionId);
    }
  }

  /// Sincroniza los detalles de una devolución con el servidor
  static Future<List<Map<String, dynamic>>> sincronizarDetallesDevolucion(
    int devolucionId,
  ) async {
    try {
      print("Obteniendo detalles de devolución ID $devolucionId del servidor");
      final service = DevolucionesService();
      final detalles = await service.getDevolucionDetalles(devolucionId);

      // Convertir a formato Map para almacenamiento
      final List<Map<String, dynamic>> detallesMap = detalles
          .map((detalle) => detalle.toJson())
          .toList();

      print(
        "Se sincronizaron ${detallesMap.length} detalles para la devolución ID $devolucionId",
      );
      return detallesMap;
    } catch (e) {
      print("Error al sincronizar detalles de devolución ID $devolucionId: $e");
      return [];
    }
  }

  /// Guarda los detalles de una devolución en almacenamiento local
  static Future<void> guardarDetallesDevolucion(
    int devolucionId,
    List<Map<String, dynamic>> detalles,
  ) async {
    try {
      // Primero leemos el mapa completo de detalles existente
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);

      // Creamos o actualizamos el mapa de detalles por ID de devolución
      Map<String, List<Map<String, dynamic>>> allDetalles = {};

      if (existingData != null && existingData.isNotEmpty) {
        allDetalles = Map<String, List<Map<String, dynamic>>>.from(
          jsonDecode(existingData) as Map<dynamic, dynamic>,
        );
      }

      // Actualizamos los detalles para esta devolución específica
      allDetalles[devolucionId.toString()] = detalles;

      // Guardamos el mapa completo actualizado
      await _secureStorage.write(key: key, value: jsonEncode(allDetalles));

      print(
        "Guardados ${detalles.length} detalles para devolución ID $devolucionId",
      );
    } catch (e) {
      print("Error al guardar detalles de devolución ID $devolucionId: $e");
      rethrow;
    }
  }

  /// Obtiene los detalles de una devolución almacenados localmente
  static Future<List<Map<String, dynamic>>> obtenerDetallesDevolucionLocal(
    int devolucionId,
  ) async {
    try {
      print(
        "Obteniendo detalles de devolución ID $devolucionId del almacenamiento local",
      );
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);

      if (existingData == null || existingData.isEmpty) {
        print("No hay datos de detalles almacenados localmente");
        return [];
      }

      // Obtenemos el mapa completo de detalles
      Map<String, dynamic> allDetalles = jsonDecode(existingData);

      // Obtenemos los detalles para esta devolución específica
      final detallesDevolucion = allDetalles[devolucionId.toString()];

      if (detallesDevolucion == null) {
        print(
          "No hay detalles almacenados para la devolución ID $devolucionId",
        );
        return [];
      }

      final List<Map<String, dynamic>> detalles =
          List<Map<String, dynamic>>.from(detallesDevolucion as List);

      print(
        "Se encontraron ${detalles.length} detalles para la devolución ID $devolucionId",
      );
      return detalles;
    } catch (e) {
      print("Error al obtener detalles de devolución ID $devolucionId: $e");
      return [];
    }
  }
}
