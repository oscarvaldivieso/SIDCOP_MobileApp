import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';

/// Servicio offline para operaciones relacionadas con devoluciones.
class DevolucionesOffline {
  // Nombres de archivos para almacenar datos
  static const String _archivoDevolucionesHistorial =
      "devoluciones_historial.json";
  static const String _archivoDetallesDevolucion = "devoluciones_detalles.json";
  static const String _archivoDevolucionesPendientes =
      "devoluciones_pendientes.json";
  static const String _archivoDevolucionesSyncErrors =
      "devoluciones_sync_errors.json";
  static const String _archivoFacturasCreate =
      "devoluciones_create_facturas.json";
  static const String _archivoDireccionesCreate =
      "devoluciones_create_direcciones.json";
  static const String _archivoProductosPorFactura =
      "devoluciones_productos_por_factura.json";

  /// Guarda devoluciones pendientes en almacenamiento local
  static Future<void> guardarDevolucionesPendientes(
    List<Map<String, dynamic>> devoluciones,
  ) async {
    await guardarJson(_archivoDevolucionesPendientes, devoluciones);
  }

  /// Guarda la lista de facturas usadas por la pantalla crear devolución
  static Future<void> guardarFacturasCreate(
    List<Map<String, dynamic>> facturas,
  ) async {
    try {
      await guardarJson(_archivoFacturasCreate, facturas);
    } catch (e) {}
  }

  /// Obtiene la lista de facturas guardadas para la pantalla crear devolución
  static Future<List<Map<String, dynamic>>> obtenerFacturasCreateLocal() async {
    try {
      final raw = await leerJson(_archivoFacturasCreate);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Guarda la lista de direcciones/clientes usadas por la pantalla crear devolución
  static Future<void> guardarDireccionesCreate(
    List<Map<String, dynamic>> direcciones,
  ) async {
    try {
      await guardarJson(_archivoDireccionesCreate, direcciones);
    } catch (e) {}
  }

  /// Obtiene las direcciones/clientes guardadas para la pantalla crear devolución
  static Future<List<Map<String, dynamic>>>
  obtenerDireccionesCreateLocal() async {
    try {
      final raw = await leerJson(_archivoDireccionesCreate);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Guarda los productos asociados a una factura para uso offline
  static Future<void> guardarProductosPorFactura(
    int facturaId,
    List<dynamic> productos,
  ) async {
    try {
      final key = "json:$_archivoProductosPorFactura";
      final existing = await _secureStorage.read(key: key);
      Map<String, dynamic> map = {};
      if (existing != null && existing.isNotEmpty) {
        try {
          map = jsonDecode(existing) as Map<String, dynamic>;
        } catch (_) {
          map = {};
        }
      }

      // Intentar descargar y reemplazar imágenes por rutas locales
      final List<dynamic> processed = [];
      for (var producto in productos) {
        try {
          if (producto is Map && producto.containsKey('prod_Imagen')) {
            final img = producto['prod_Imagen'];
            if (img is String &&
                img.trim().isNotEmpty &&
                img.startsWith('http')) {
              try {
                final prodId =
                    producto['prod_Id'] ??
                    DateTime.now().millisecondsSinceEpoch;
                final localPath = await _downloadAndSaveImage(
                  img,
                  facturaId,
                  prodId,
                );
                // Clonar el mapa y reemplazar la ruta
                final Map<String, dynamic> clone = Map<String, dynamic>.from(
                  producto,
                );
                clone['prod_Imagen'] = localPath;
                processed.add(clone);
                continue;
              } catch (imgErr) {
                // continuar y guardar la referencia original
              }
            }
          }
        } catch (_) {
          // en caso de estructura inesperada, seguir
        }
        processed.add(producto);
      }

      // Guardar la lista de productos (serializable) bajo la clave facturaId
      map[facturaId.toString()] = processed;
      await _secureStorage.write(key: key, value: jsonEncode(map));
    } catch (e) {
      rethrow;
    }
  }

  /// Descarga una imagen desde [url] y la guarda en la carpeta de documentos
  /// bajo subcarpeta 'devoluciones_images'. Devuelve la ruta local del archivo
  /// o la misma URL si falla la descarga.
  static Future<String> _downloadAndSaveImage(
    String url,
    int facturaId,
    dynamic prodId,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(dir.path, 'devoluciones_images'));
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      final ext = p.extension(Uri.parse(url).path).isNotEmpty
          ? p.extension(Uri.parse(url).path)
          : '.jpg';
      final filename = '${facturaId}_$prodId$ext';
      final filePath = p.join(imagesDir.path, filename);
      final file = File(filePath);

      // Si el archivo ya existe, devolverlo inmediatamente (idempotencia)
      if (await file.exists()) {
        return filePath;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await file.writeAsBytes(bytes);
        return filePath;
      } else {
        return url;
      }
    } catch (e) {
      return url;
    }
  }

  /// Obtiene los productos guardados para una factura específica
  static Future<List<Map<String, dynamic>>> obtenerProductosPorFacturaLocal(
    int facturaId,
  ) async {
    try {
      final key = "json:$_archivoProductosPorFactura";
      final existing = await _secureStorage.read(key: key);
      if (existing == null || existing.isEmpty) return [];

      final Map<String, dynamic> map = jsonDecode(existing);
      final raw = map[facturaId.toString()];
      if (raw == null) return [];

      // Asegurar que devolvemos List<Map<String,dynamic>>
      final List<dynamic> rawList = raw as List<dynamic>;
      final List<Map<String, dynamic>> productos = rawList
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
      return productos;
    } catch (e) {
      return [];
    }
  }

  /// Obtiene las devoluciones pendientes almacenadas localmente
  static Future<List<Map<String, dynamic>>>
  obtenerDevolucionesPendientesLocal() async {
    final raw = await leerJson(_archivoDevolucionesPendientes);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  /// Agrega una devolución pendiente localmente (evita duplicados por devo_Id)
  static Future<bool> agregarDevolucionPendienteLocal(
    Map<String, dynamic> devolucion,
  ) async {
    final lista = await obtenerDevolucionesPendientesLocal();
    final id =
        devolucion['devo_Id'] ?? devolucion['devoId'] ?? devolucion['id'];
    if (id != null) {
      for (final item in lista) {
        final itemId = item['devo_Id'] ?? item['devoId'] ?? item['id'];
        if (itemId == id) {
          // Ya existe una devolución pendiente con ese ID
          return false;
        }
      }
    }
    lista.add(devolucion);
    await guardarDevolucionesPendientes(lista);
    return true;
  }

  /// Verifica si hay devoluciones pendientes
  static Future<bool> existenDevolucionesPendientes() async {
    final pendientes = await obtenerDevolucionesPendientesLocal();
    return pendientes.isNotEmpty;
  }

  // Instancia de secure storage para almacenar datos
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo`.
  /// Escritura atómica: se guarda el JSON como string en secure storage bajo la clave "json:<nombreArchivo>".
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      // Intenta determinar el tipo de objeto que estamos guardando para mejorar la depuración
      String tipoObjeto = "desconocido";
      if (objeto is List) {
        tipoObjeto = "Lista de ${objeto.length} elementos";
        if (objeto.isNotEmpty) {
          tipoObjeto += " (primer elemento tipo: ${objeto.first.runtimeType})";
        }
      } else if (objeto is Map) {
        tipoObjeto = "Mapa con ${objeto.length} claves";
      } else {
        tipoObjeto = objeto.runtimeType.toString();
      }

      // Validación de tamaño para evitar errores de memoria
      final contenido = jsonEncode(objeto);
      final sizeInBytes = contenido.length * 2; // Aproximación para UTF-16
      final sizeInKB = sizeInBytes / 1024;

      // Si los datos son grandes (más de 1MB), advertir
      if (sizeInKB > 1024) {}

      final key = "json:$nombreArchivo";
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {}
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = "json:$nombreArchivo";
      final s = await _secureStorage.read(key: key);

      if (s == null) {
        return null;
      }

      // Validación de tamaño para depuración
      final sizeInKB = (s.length * 2) / 1024; // Aproximación para UTF-16

      try {
        final decodedData = jsonDecode(s);

        // Determinar el tipo de datos leído para mejorar la depuración
        if (decodedData is List) {
          if (decodedData.isNotEmpty) {}
        } else if (decodedData is Map) {
          if (decodedData.isNotEmpty) {}
        } else {}

        return decodedData;
      } catch (decodeError) {
        // Intentar ver qué está mal con los datos
        if (s.length > 100) {
        } else {}

        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza las devoluciones con el servidor y guarda el resultado localmente
  static Future<List<Map<String, dynamic>>> sincronizarDevoluciones() async {
    try {
      // Obtener devoluciones del servidor
      final service = DevolucionesService();
      final devoluciones = await service.listarDevoluciones();

      // Convertir a formato Map para almacenamiento
      final List<Map<String, dynamic>> devolucionesMap = devoluciones
          .map((dev) => dev.toJson())
          .toList();

      // Guardar inmediatamente los datos para asegurar que están disponibles offline
      if (devolucionesMap.isNotEmpty) {
        try {
          await guardarDevolucionesHistorial(devolucionesMap);
        } catch (saveError) {
          // Log mínimo para diagnóstico
        }
      }

      return devolucionesMap;
    } catch (e) {
      // Solo loggear errores críticos

      // Si ocurre un error, intentar devolver lo que está guardado localmente
      try {
        final devolucionesLocales = await obtenerDevolucionesLocal();
        return devolucionesLocales;
      } catch (localError) {
        return []; // Si todo falla, devolver una lista vacía
      }
    }
  }

  /// Guarda devoluciones en almacenamiento local
  static Future<void> guardarDevolucionesHistorial(
    List<Map<String, dynamic>> devoluciones,
  ) async {
    try {
      if (devoluciones.isEmpty) {
        return; // No guardar lista vacía
      }

      // Verificar que tenemos los campos necesarios en los objetos
      for (int i = 0; i < devoluciones.length; i++) {
        final devolucion = devoluciones[i];
        if (!devolucion.containsKey('devo_Id')) {}
      }

      // Guardar los datos
      await guardarJson(_archivoDevolucionesHistorial, devoluciones);

      // Verificar que se guardaron correctamente leyéndolos de vuelta
      final verificacion = await leerJson(_archivoDevolucionesHistorial);
      if (verificacion != null &&
          verificacion is List &&
          verificacion.isNotEmpty) {
      } else {}

      // Imprimir todos los IDs almacenados después de la sincronización
      await imprimirDetallesDevolucionesGuardados();
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda un registro de error de sincronización de devoluciones en almacenamiento local
  static Future<void> guardarErrorSincronizacionDevoluciones(
    Map<String, dynamic> errorEntry,
  ) async {
    try {
      final existing = await leerJson(_archivoDevolucionesSyncErrors);
      List<Map<String, dynamic>> list = [];
      if (existing != null && existing is List) {
        try {
          list = List<Map<String, dynamic>>.from(existing);
        } catch (_) {
          // Si el formato es inesperado, reiniciar la lista
          list = [];
        }
      }
      list.add(errorEntry);
      await guardarJson(_archivoDevolucionesSyncErrors, list);
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene los errores de sincronización guardados localmente
  static Future<List<Map<String, dynamic>>>
  obtenerErroresSincronizacionLocal() async {
    final raw = await leerJson(_archivoDevolucionesSyncErrors);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Limpia el archivo de errores de sincronización local
  static Future<void> limpiarErroresSincronizacion() async {
    try {
      final key = "json:$_archivoDevolucionesSyncErrors";
      await _secureStorage.delete(key: key);
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene las devoluciones guardadas localmente
  static Future<List<Map<String, dynamic>>> obtenerDevolucionesLocal() async {
    try {
      final data = await leerJson(_archivoDevolucionesHistorial);

      if (data == null) {
        return [];
      }

      // Manejar diferentes tipos de datos para aumentar robustez
      List<Map<String, dynamic>> devoluciones = [];

      if (data is List) {
        // Convertir cada elemento a Map<String, dynamic>
        for (int i = 0; i < data.length; i++) {
          var item = data[i];
          try {
            if (item is Map) {
              // Crear un nuevo mapa asegurándose de que las claves sean strings
              Map<String, dynamic> devolucionMap = {};
              item.forEach((key, value) {
                devolucionMap[key.toString()] = value;
              });

              // Verificación adicional para asegurar que la devolución es válida
              if (!devolucionMap.containsKey('devo_Id')) {
                // Si no tiene devo_Id, buscar otras variantes posibles
                if (devolucionMap.containsKey('devoId')) {
                  devolucionMap['devo_Id'] = devolucionMap['devoId'];
                } else if (devolucionMap.containsKey('id')) {
                  devolucionMap['devo_Id'] = devolucionMap['id'];
                } else {}
              }

              devoluciones.add(devolucionMap);
            } else {}
          } catch (itemError) {}
        }
      } else if (data is Map) {
        // Verificar si es un mapa de ID -> devolución
        bool esMapaDeDevoluciones = false;
        data.forEach((key, value) {
          if (value is Map &&
              (value.containsKey('devo_Id') || value.containsKey('devoId'))) {
            esMapaDeDevoluciones = true;
          }
        });

        if (esMapaDeDevoluciones) {
          data.forEach((key, value) {
            if (value is Map) {
              Map<String, dynamic> devolucionMap = {};
              value.forEach((k, v) {
                devolucionMap[k.toString()] = v;
              });
              devoluciones.add(devolucionMap);
            }
          });
        } else {
          // Si solo es un objeto de devolución único
          Map<String, dynamic> devolucionMap = {};
          data.forEach((key, value) {
            devolucionMap[key.toString()] = value;
          });
          devoluciones.add(devolucionMap);
        }
      } else {}

      // Registro detallado para depurar
      if (devoluciones.isNotEmpty) {
        // Verificar estructura esperada
        final primeraDevolucion = devoluciones.first;
        if (primeraDevolucion['devo_Id'] != null) {
        } else {}

        // Si tenemos devoluciones pero ninguna tiene devo_Id, puede ser un problema de formato
        bool algunaTieneId = false;
        for (var dev in devoluciones) {
          if (dev.containsKey('devo_Id') ||
              dev.containsKey('devoId') ||
              dev.containsKey('id')) {
            algunaTieneId = true;
            break;
          }
        }

        if (!algunaTieneId && devoluciones.length > 0) {}
      } else {}

      return devoluciones;
    } catch (e) {
      // Intento de recuperación de emergencia
      try {
        print("🔄 Intentando método alternativo de lectura...");
        final key = "json:$_archivoDevolucionesHistorial";
        final String? rawData = await _secureStorage.read(key: key);

        if (rawData != null && rawData.isNotEmpty) {
          // Intentar decodificar manualmente
          final jsonData = jsonDecode(rawData);

          if (jsonData is List) {
            List<Map<String, dynamic>> devoluciones = [];
            for (var item in jsonData) {
              if (item is Map) {
                Map<String, dynamic> map = {};
                item.forEach((k, v) => map[k.toString()] = v);
                devoluciones.add(map);
              }
            }

            return devoluciones;
          }
        }

        return [];
      } catch (emergencyError) {
        return [];
      }
    }
  }

  /// Sincroniza y guarda todas las devoluciones
  static Future<List<Map<String, dynamic>>> sincronizarYGuardarDevoluciones({
    bool forzarSincronizacionDetalles = false,
    bool isOnline = true, // Indicar si estamos en modo online u offline
  }) async {
    try {
      List<Map<String, dynamic>> devoluciones;

      if (isOnline) {
        // Obtener devoluciones del servidor
        devoluciones = await sincronizarDevoluciones();

        // Guardar en almacenamiento local
        if (devoluciones.isNotEmpty) {
          await guardarDevolucionesHistorial(devoluciones);
        }

        // Si se solicita sincronización forzada de detalles
        if (forzarSincronizacionDetalles) {
          try {
            await sincronizarDetallesDeTodasLasDevoluciones();
          } catch (e) {}
        }
      } else {
        // En modo offline, obtener directamente del almacenamiento local
        devoluciones = await obtenerDevolucionesLocal();
      }

      return devoluciones;
    } catch (e) {
      // Intentar devolver lo que está guardado localmente
      try {
        final devolucionesLocales = await obtenerDevolucionesLocal();
        return devolucionesLocales;
      } catch (localError) {
        return []; // Si todo falla, devolver lista vacía
      }
    }
  }

  /// Sincroniza y guarda los detalles de todas las devoluciones
  static Future<void> sincronizarDetallesDeTodasLasDevoluciones() async {
    try {
      // Primero obtenemos todas las devoluciones
      final devoluciones = await obtenerDevolucionesLocal();
      if (devoluciones.isEmpty) {
        return;
      }

      // Para cada devolución, sincronizamos sus detalles
      int contadorExitosos = 0;
      int totalDetallesSincronizados = 0;

      // Procesar las devoluciones en bloques para no sobrecargar la memoria
      final int blockSize = 10; // Procesar 10 devoluciones a la vez

      for (int i = 0; i < devoluciones.length; i += blockSize) {
        final int fin = (i + blockSize < devoluciones.length)
            ? i + blockSize
            : devoluciones.length;
      }

      // Imprimir todos los IDs almacenados después de la sincronización
      await imprimirDetallesDevolucionesGuardados();
    } catch (e) {}
  }

  /// Convierte una lista de Maps a una lista de DevolucionesViewModel
  ///
  /// Esta función implementa una conversión robusta para manejar errores individuales
  /// y maximizar la cantidad de modelos que pueden ser convertidos correctamente.
  static List<DevolucionesViewModel> convertirAModelos(
    List<Map<String, dynamic>> devoluciones,
  ) {
    try {
      // Usar una conversión robusta que maneja errores individuales
      List<DevolucionesViewModel> modelos = [];
      int errores = 0;

      for (int i = 0; i < devoluciones.length; i++) {
        try {
          final devolucion = devoluciones[i];

          // Verificar y corregir campos críticos si es necesario
          _verificarYCorregirCampos(devolucion, i);

          // Intentar convertir al modelo
          final modelo = DevolucionesViewModel.fromJson(devolucion);
          modelos.add(modelo);
        } catch (e) {
          errores++;
        }
      }

      return modelos;
    } catch (e) {
      return [];
    }
  }

  /// Verifica y corrige campos críticos en el mapa de devolución
  static void _verificarYCorregirCampos(
    Map<String, dynamic> devolucion,
    int index,
  ) {
    // Verificar campo devo_Id / devoId
    if (!devolucion.containsKey('devo_Id') &&
        devolucion.containsKey('devoId')) {
      devolucion['devo_Id'] = devolucion['devoId'];
    }

    // Verificar campo devo_Fecha / devoFecha
    if (!devolucion.containsKey('devo_Fecha') &&
        devolucion.containsKey('devoFecha')) {
      devolucion['devo_Fecha'] = devolucion['devoFecha'];
    }

    // Verificar campo devo_Motivo / devoMotivo
    if (!devolucion.containsKey('devo_Motivo') &&
        devolucion.containsKey('devoMotivo')) {
      devolucion['devo_Motivo'] = devolucion['devoMotivo'];
    }

    // Asegurar que los campos críticos existan (con valores por defecto si es necesario)
    if (!devolucion.containsKey('devo_Id') &&
        !devolucion.containsKey('devoId')) {}

    if (!devolucion.containsKey('devo_Fecha') &&
        !devolucion.containsKey('devoFecha')) {
      // Asignar fecha actual como fallback
      devolucion['devo_Fecha'] = DateTime.now().toIso8601String();
    }

    // Convertir formato de fecha si es necesario
    final fechaValue = devolucion['devo_Fecha'] ?? devolucion['devoFecha'];
    if (fechaValue is String &&
        !fechaValue.contains('T') &&
        !fechaValue.contains(' ')) {
      // Intentar convertir a formato ISO
      try {
        final DateTime fecha = DateTime.parse(fechaValue);
        devolucion['devo_Fecha'] = fecha.toIso8601String();
      } catch (e) {}
    }
  }

  /// Imprime el contenido completo de devoluciones_detalles.json y los IDs presentes
  static Future<void> imprimirDetallesDevolucionesGuardados() async {
    try {
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);
      if (existingData == null || existingData.isEmpty) {
        return;
      }
      final Map<String, dynamic> allDetalles = jsonDecode(existingData);
    } catch (e) {}
  }

  /// Verifica si existen detalles para una devolución específica
  static Future<bool> existenDetallesParaDevolicion(int devolucionId) async {
    try {
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);

      if (existingData == null || existingData.isEmpty) {
        return false;
      }

      final Map<String, dynamic> allDetalles = jsonDecode(existingData);
      final detalles = allDetalles[devolucionId.toString()];

      return detalles != null && (detalles as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Limpia completamente el almacenamiento local de detalles de devoluciones
  static Future<void> limpiarDetallesDevoluciones() async {
    try {
      final key = "json:$_archivoDetallesDevolucion";
      await _secureStorage.delete(key: key);
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza y guarda los detalles de una devolución específica
  ///
  /// Parámetros:
  /// - `devolucionId`: ID de la devolución para la que se obtendrán detalles
  /// - `isOnline`: Indica si estamos en modo online u offline (por defecto true)
  /// - `forceSync`: Fuerza sincronización incluso si ya hay datos locales (por defecto false)
  static Future<List<Map<String, dynamic>>>
  sincronizarYGuardarDetallesDevolucion(
    int devolucionId, {
    bool isOnline = true,
    bool forceSync = false,
  }) async {
    try {
      // Si no estamos online, vamos directamente al almacenamiento local
      if (!isOnline) {
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false, // Forzar modo offline
        );
      }

      // Verificar si ya tenemos los detalles guardados localmente
      if (!forceSync) {
        final tieneDetalles = await existenDetallesParaDevolicion(devolucionId);
        if (tieneDetalles) {
          return await obtenerDetallesDevolucionLocal(
            devolucionId,
            isOnline: false, // No intentar sincronizar de nuevo
          );
        }
      }

      // Si no hay detalles locales o se fuerza la sincronización, obtenerlos del servidor
      final detalles = await sincronizarDetallesDevolucion(devolucionId);

      // Verificar si realmente se obtuvieron detalles del servidor
      if (detalles.isEmpty) {
        // Intentar obtener los detalles locales como último recurso
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false, // No intentar sincronizar de nuevo
        );
      }

      // Si hay detalles, guardarlos localmente
      // Antes de guardar, validar la estructura de los datos
      bool datosValidos = true;
      for (int i = 0; i < detalles.length; i++) {
        final detalle = detalles[i];
        if (!(detalle is Map)) {
          datosValidos = false;
          break;
        }
      }

      if (!datosValidos) {
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false,
        );
      }

      // Guardar los detalles en el almacenamiento local
      await guardarDetallesDevolucion(devolucionId, detalles);

      // Asegurarnos de que lo que devolvemos es un List<Map<String, dynamic>> válido
      List<Map<String, dynamic>> detallesMapSeguro = [];
      for (var detalle in detalles) {
        if (detalle is Map) {
          Map<String, dynamic> detalleMap = {};
          detalle.forEach((key, value) {
            if (key is String) {
              detalleMap[key] = value;
            }
          });
          detallesMapSeguro.add(detalleMap);
        }
      }

      return detallesMapSeguro;
    } catch (e) {
      // Intentar devolver lo que está guardado localmente como mecanismo de recuperación
      try {
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false, // No intentar sincronizar de nuevo
        );
      } catch (localError) {
        return []; // Devolver lista vacía si todo falla
      }
    }
  }

  /// Sincroniza los detalles de una devolución con el servidor
  static Future<List<dynamic>> sincronizarDetallesDevolucion(
    int devolucionId,
  ) async {
    try {
      final service = DevolucionesService();
      final detalles = await service.getDevolucionDetalles(devolucionId);

      // Verificar si la respuesta contiene datos
      if (detalles.isEmpty) {
        return [];
      }

      // Convertir a formato Map para almacenamiento
      final detallesMap = detalles.map((detalle) => detalle.toJson()).toList();

      return detallesMap;
    } catch (e) {
      return [];
    }
  }

  /// Guarda los detalles de una devolución en almacenamiento local
  static Future<void> guardarDetallesDevolucion(
    int devolucionId,
    List<dynamic> detalles,
  ) async {
    try {
      // Primero leemos el mapa completo de detalles existente
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);

      // Creamos o actualizamos el mapa de detalles por ID de devolución
      Map<String, dynamic> allDetalles = {};

      if (existingData != null && existingData.isNotEmpty) {
        allDetalles = jsonDecode(existingData) as Map<String, dynamic>;
      }

      // Convertimos los detalles a una lista de mapas segura
      List<Map<String, dynamic>> detallesMapSeguro = [];

      // Procesar cada detalle y asegurarnos de que sea un Map<String, dynamic>
      for (var detalle in detalles) {
        if (detalle is Map) {
          // Convertir a Map<String, dynamic> explícitamente
          Map<String, dynamic> detalleMap = {};
          detalle.forEach((key, value) {
            if (key is String) {
              detalleMap[key] = value;
            }
          });
          detallesMapSeguro.add(detalleMap);
        }
      }

      // Actualizamos los detalles para esta devolución específica
      allDetalles[devolucionId.toString()] = detallesMapSeguro;

      // Guardamos el mapa completo actualizado
      await _secureStorage.write(key: key, value: jsonEncode(allDetalles));
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene los detalles de una devolución almacenados localmente
  /// Si isOnline es true, intentará sincronizar con el servidor si no encuentra datos locales
  static Future<List<Map<String, dynamic>>> obtenerDetallesDevolucionLocal(
    int devolucionId, {
    bool isOnline = false, // Por defecto, asumimos que estamos offline
  }) async {
    try {
      // Loggear el contenido completo antes de leer
      await imprimirDetallesDevolucionesGuardados();
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);

      if (existingData == null || existingData.isEmpty) {
        // Solo intentar sincronizar si estamos online
        if (isOnline) {
          try {
            final detallesServidor = await sincronizarDetallesDevolucion(
              devolucionId,
            );
            // Convertir los detalles a Map<String, dynamic>
            List<Map<String, dynamic>> detallesMap = [];
            for (var detalle in detallesServidor) {
              Map<String, dynamic> detalleMap = {};
              (detalle as Map).forEach((key, value) {
                detalleMap[key.toString()] = value;
              });
              detallesMap.add(detalleMap);
            }
            return detallesMap;
          } catch (syncError) {
            return [];
          }
        } else {
          return [];
        }
      }

      // Obtenemos el mapa completo de detalles
      Map<String, dynamic> allDetalles = jsonDecode(existingData);

      // Obtenemos los detalles para esta devolución específica
      final detallesDevolucion = allDetalles[devolucionId.toString()];

      if (detallesDevolucion == null) {
        // Solo intentar sincronizar si estamos online
        if (isOnline) {
          try {
            final detallesServidor = await sincronizarDetallesDevolucion(
              devolucionId,
            );
            // Convertir los detalles a Map<String, dynamic>
            List<Map<String, dynamic>> detallesMap = [];
            for (var detalle in detallesServidor) {
              Map<String, dynamic> detalleMap = {};
              (detalle as Map).forEach((key, value) {
                detalleMap[key.toString()] = value;
              });
              detallesMap.add(detalleMap);
            }
            return detallesMap;
          } catch (syncError) {
            return [];
          }
        } else {
          return [];
        }
      }

      // Asegurarnos de que los detalles se conviertan correctamente a Map<String, dynamic>
      final List<dynamic> rawDetalles = detallesDevolucion as List;
      final List<Map<String, dynamic>> detalles = [];

      for (var detalle in rawDetalles) {
        if (detalle is Map) {
          Map<String, dynamic> detalleMap = {};
          detalle.forEach((key, value) {
            detalleMap[key.toString()] = value;
          });
          detalles.add(detalleMap);
        }
      }

      return detalles;
    } catch (e) {
      return [];
    }
  }

  /// Intenta sincronizar y enviar las devoluciones pendientes al servidor.
  /// Devuelve un mapa con conteos de exito/fallo.
  static Future<Map<String, int>> sincronizarPendientesDevoluciones() async {
    try {
      final pendientes = await obtenerDevolucionesPendientesLocal();
      if (pendientes.isEmpty) {
        return {'success': 0, 'failed': 0};
      }

      final service = DevolucionesService();
      int success = 0;
      int failed = 0;

      // Lista mutable de pendientes que permanecerán si fallan
      final List<Map<String, dynamic>> remaining =
          List<Map<String, dynamic>>.from(pendientes);

      for (final pend in List<Map<String, dynamic>>.from(pendientes)) {
        try {
          final clieId = pend['clie_Id'] ?? pend['clieId'];
          final factId = pend['fact_Id'] ?? pend['factId'];
          final devoMotivo = pend['devo_Motivo'] ?? pend['devoMotivo'] ?? '';
          final usuaCreacion =
              pend['usua_Creacion'] ?? pend['usuaCreacion'] ?? 0;
          final detalles = pend['detalles'] ?? [];
          DateTime? devoFecha;
          final devoFechaRaw = pend['devo_Fecha'] ?? pend['devoFecha'];
          if (devoFechaRaw != null) {
            try {
              devoFecha = DateTime.tryParse(devoFechaRaw.toString());
            } catch (_) {
              devoFecha = null;
            }
          }

          // Ensure detalles is List<Map<String, dynamic>>
          List<Map<String, dynamic>> detallesCast = [];
          try {
            for (var d in detalles) {
              if (d is Map) {
                detallesCast.add(Map<String, dynamic>.from(d));
              }
            }
          } catch (_) {
            // Si el formato no es iterable, dejar la lista vacía
          }

          final response = await service.insertarDevolucionConFacturaAjustada(
            clieId: clieId,
            factId: factId,
            devoMotivo: devoMotivo,
            usuaCreacion: usuaCreacion,
            detalles: detallesCast,
            devoFecha: devoFecha,
            crearNuevaFactura: true,
          );

          if (response['success'] == true) {
            success++;
            // eliminar de la lista remaining: eliminar el objeto pendiente procesado directamente
            try {
              // Intentar remover por referencia/igualdad del mapa pending
              remaining.remove(pend);
            } catch (_) {
              // fallback: intentar eliminar por match de campos clave (cliente+factura+fecha)
              final clieIdP = pend['clie_Id'] ?? pend['clieId'];
              final factIdP = pend['fact_Id'] ?? pend['factId'];
              final fechaP = pend['devo_Fecha'] ?? pend['devoFecha'];
              remaining.removeWhere((r) {
                final clieIdR = r['clie_Id'] ?? r['clieId'];
                final factIdR = r['fact_Id'] ?? r['factId'];
                final fechaR = r['devo_Fecha'] ?? r['devoFecha'];
                return clieIdR == clieIdP &&
                    factIdR == factIdP &&
                    fechaR == fechaP;
              });
            }

            // Agregar la devolución creada al historial local si viene en la respuesta
            final created =
                response['devolucion']?['data'] ??
                response['devolucion'] ??
                response;
            try {
              final existing =
                  await leerJson(_archivoDevolucionesHistorial) as dynamic;
              List<Map<String, dynamic>> histor = [];
              if (existing != null && existing is List) {
                histor = List<Map<String, dynamic>>.from(existing);
              }
              if (created is Map) {
                // evitar duplicados en el historial
                final createdId =
                    created['devo_Id'] ?? created['devoId'] ?? created['id'];
                bool already = false;
                if (createdId != null) {
                  for (var h in histor) {
                    final hid = h['devo_Id'] ?? h['devoId'] ?? h['id'];
                    if (hid == createdId) {
                      already = true;
                      break;
                    }
                  }
                } else {
                  // fallback: comparar por cliente+factura+fecha
                  final c = created['clie_Id'] ?? created['clieId'];
                  final f = created['fact_Id'] ?? created['factId'];
                  final dt = created['devo_Fecha'] ?? created['devoFecha'];
                  for (var h in histor) {
                    if ((h['clie_Id'] ?? h['clieId']) == c &&
                        (h['fact_Id'] ?? h['factId']) == f &&
                        (h['devo_Fecha'] ?? h['devoFecha']) == dt) {
                      already = true;
                      break;
                    }
                  }
                }
                if (!already) {
                  histor.add(Map<String, dynamic>.from(created));
                }
              }
            } catch (histErr) {}
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
        }
      }

      // Guardar los pendientes que quedaron
      try {
        await guardarDevolucionesPendientes(remaining);
      } catch (saveErr) {}

      return {'success': success, 'failed': failed};
    } catch (e) {
      return {'success': 0, 'failed': 0};
    }
  }
}
