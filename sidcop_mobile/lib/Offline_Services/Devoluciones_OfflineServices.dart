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
      print('Facturas para create guardadas localmente (${facturas.length})');
    } catch (e) {
      print('Error guardando facturas create: $e');
    }
  }

  /// Obtiene la lista de facturas guardadas para la pantalla crear devolución
  static Future<List<Map<String, dynamic>>> obtenerFacturasCreateLocal() async {
    try {
      final raw = await leerJson(_archivoFacturasCreate);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      print('Error obteniendo facturas create local: $e');
      return [];
    }
  }

  /// Guarda la lista de direcciones/clientes usadas por la pantalla crear devolución
  static Future<void> guardarDireccionesCreate(
    List<Map<String, dynamic>> direcciones,
  ) async {
    try {
      await guardarJson(_archivoDireccionesCreate, direcciones);
      print(
        'Direcciones para create guardadas localmente (${direcciones.length})',
      );
    } catch (e) {
      print('Error guardando direcciones create: $e');
    }
  }

  /// Obtiene las direcciones/clientes guardadas para la pantalla crear devolución
  static Future<List<Map<String, dynamic>>>
  obtenerDireccionesCreateLocal() async {
    try {
      final raw = await leerJson(_archivoDireccionesCreate);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      print('Error obteniendo direcciones create local: $e');
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
                print(
                  'Error descargando imagen para prod ${producto['prod_Id']}: $imgErr',
                );
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
      print(
        'Productos guardados localmente para factura $facturaId (con imágenes procesadas si fue posible)',
      );
    } catch (e) {
      print('Error guardando productos por factura $facturaId: $e');
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
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(dir.path, 'devoluciones_images'));
        if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

        final ext = p.extension(Uri.parse(url).path).isNotEmpty
            ? p.extension(Uri.parse(url).path)
            : '.jpg';
        final filename = '${facturaId}_$prodId$ext';
        final filePath = p.join(imagesDir.path, filename);
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Imagen guardada localmente en $filePath');
        return filePath;
      } else {
        print('Fallo al descargar imagen: ${response.statusCode}');
        return url;
      }
    } catch (e) {
      print('Error descargando imagen $url: $e');
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
      print(
        'Leídos ${productos.length} productos locales para factura $facturaId',
      );
      return productos;
    } catch (e) {
      print('Error leyendo productos locales para factura $facturaId: $e');
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
      print("Guardando en $nombreArchivo...");

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
      print("Tipo de datos a guardar: $tipoObjeto");

      // Validación de tamaño para evitar errores de memoria
      final contenido = jsonEncode(objeto);
      final sizeInBytes = contenido.length * 2; // Aproximación para UTF-16
      final sizeInKB = sizeInBytes / 1024;

      print("Tamaño de los datos: ${sizeInKB.toStringAsFixed(2)} KB");

      // Si los datos son grandes (más de 1MB), advertir
      if (sizeInKB > 1024) {
        print(
          "⚠ ADVERTENCIA: Guardando un JSON muy grande (${(sizeInKB / 1024).toStringAsFixed(2)} MB)",
        );
      }

      final key = "json:$nombreArchivo";
      await _secureStorage.write(key: key, value: contenido);
      print("✓ Datos guardados exitosamente en $nombreArchivo");
    } catch (e) {
      print("❌ Error al guardar JSON $nombreArchivo: $e");
      if (e.toString().contains("Exceeds maximum size")) {
        print(
          "El JSON es demasiado grande para FlutterSecureStorage. Considere dividirlo en fragmentos más pequeños.",
        );
      }
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      print("Leyendo archivo $nombreArchivo...");
      final key = "json:$nombreArchivo";
      final s = await _secureStorage.read(key: key);

      if (s == null) {
        print("❌ Archivo $nombreArchivo no encontrado en el almacenamiento");
        return null;
      }

      // Validación de tamaño para depuración
      final sizeInKB = (s.length * 2) / 1024; // Aproximación para UTF-16
      print("Leyendo archivo de ${sizeInKB.toStringAsFixed(2)} KB");

      try {
        final decodedData = jsonDecode(s);

        // Determinar el tipo de datos leído para mejorar la depuración
        if (decodedData is List) {
          print("✓ Leída lista con ${decodedData.length} elementos");
          if (decodedData.isNotEmpty) {
            print("  - Primer elemento tipo: ${decodedData.first.runtimeType}");
          }
        } else if (decodedData is Map) {
          print("✓ Leído mapa con ${decodedData.length} claves");
          if (decodedData.isNotEmpty) {
            print(
              "  - Claves disponibles: ${decodedData.keys.take(5).toList()}${decodedData.length > 5 ? '...' : ''}",
            );
          }
        } else {
          print("✓ Leído objeto de tipo ${decodedData.runtimeType}");
        }

        return decodedData;
      } catch (decodeError) {
        print("❌ Error al decodificar JSON desde $nombreArchivo: $decodeError");

        // Intentar ver qué está mal con los datos
        if (s.length > 100) {
          print(
            "Primeros 100 caracteres de los datos: ${s.substring(0, 100)}...",
          );
        } else {
          print("Datos completos: $s");
        }

        rethrow;
      }
    } catch (e) {
      print("❌ Error al leer JSON $nombreArchivo: $e");
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");
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

      // Verificar que los datos se han sincronizado correctamente
      if (devolucionesMap.isNotEmpty) {
        print("Primera devolución sincronizada: ${devolucionesMap.first}");

        // Guardar inmediatamente los datos para asegurar que están disponibles offline
        try {
          await guardarDevolucionesHistorial(devolucionesMap);
          print("Devoluciones guardadas localmente durante la sincronización");
        } catch (saveError) {
          print(
            "Error al guardar devoluciones durante sincronización: $saveError",
          );
        }
      }

      return devolucionesMap;
    } catch (e) {
      print("Error al sincronizar devoluciones: $e");
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");

      // Guardar información del error de sincronización localmente para diagnóstico
      try {
        final errorEntry = {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'context': 'Devoluciones/Listar',
        };
        await guardarErrorSincronizacionDevoluciones(errorEntry);
        print('✓ Error de sincronización guardado localmente');
      } catch (saveErr) {
        print('❌ No se pudo guardar el error de sincronización: $saveErr');
      }

      // Si ocurre un error, intentar devolver lo que está guardado localmente
      try {
        print("Intentando obtener devoluciones locales después del error...");
        final devolucionesLocales = await obtenerDevolucionesLocal();
        print(
          "Se encontraron ${devolucionesLocales.length} devoluciones locales después del error",
        );
        return devolucionesLocales;
      } catch (localError) {
        print("Error también al obtener devoluciones locales: $localError");
        return []; // Si todo falla, devolver una lista vacía
      }
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

      if (devoluciones.isEmpty) {
        print(
          "ADVERTENCIA: Intentando guardar una lista vacía de devoluciones",
        );
        return; // No guardar lista vacía
      }

      // Verificar que tenemos los campos necesarios en los objetos
      for (int i = 0; i < devoluciones.length; i++) {
        final devolucion = devoluciones[i];
        if (!devolucion.containsKey('devo_Id')) {
          print("ADVERTENCIA: La devolución #$i no tiene devo_Id");
          print("Claves disponibles: ${devolucion.keys.toList()}");
        }
      }

      // Guardar los datos
      await guardarJson(_archivoDevolucionesHistorial, devoluciones);

      // Verificar que se guardaron correctamente leyéndolos de vuelta
      final verificacion = await leerJson(_archivoDevolucionesHistorial);
      if (verificacion != null &&
          verificacion is List &&
          verificacion.isNotEmpty) {
        print(
          "✓ Verificación: Se guardaron ${verificacion.length} devoluciones correctamente",
        );
      } else {
        print(
          "⚠ Verificación: Los datos guardados no se leyeron correctamente",
        );
      }

      print("Devoluciones guardadas exitosamente");
    } catch (e) {
      print("Error al guardar devoluciones: $e");
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");
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
      print('Error guardando error de sincronizacion: $e');
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
      print('Error parseando errores de sincronizacion: $e');
      return [];
    }
  }

  /// Limpia el archivo de errores de sincronización local
  static Future<void> limpiarErroresSincronizacion() async {
    try {
      final key = "json:$_archivoDevolucionesSyncErrors";
      await _secureStorage.delete(key: key);
      print('Errores de sincronizacion limpiados');
    } catch (e) {
      print('Error limpiando errores de sincronizacion: $e');
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
                } else {
                  print(
                    "⚠ ADVERTENCIA: La devolución #$i no tiene un ID reconocible",
                  );
                  print("Claves disponibles: ${devolucionMap.keys.toList()}");
                }
              }

              devoluciones.add(devolucionMap);
            } else {
              print("⚠ Elemento #$i no es un mapa: ${item.runtimeType}");
            }
          } catch (itemError) {
            print("❌ Error al procesar devolución #$i: $itemError");
            print("Datos problemáticos: $item");
          }
        }
      } else if (data is Map) {
        print(
          "⚠ ADVERTENCIA: Se esperaba una lista pero se recibió un mapa. Intentando procesar...",
        );

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
          print(
            "✓ Convertido mapa de devoluciones a lista de ${devoluciones.length} elementos",
          );
        } else {
          // Si solo es un objeto de devolución único
          Map<String, dynamic> devolucionMap = {};
          data.forEach((key, value) {
            devolucionMap[key.toString()] = value;
          });
          devoluciones.add(devolucionMap);
          print("✓ Convertido objeto único a lista con 1 elemento");
        }
      } else {
        print("⚠ Tipo de datos no reconocido: ${data.runtimeType}");
      }

      print("Se encontraron ${devoluciones.length} devoluciones locales");

      // Registro detallado para depurar
      if (devoluciones.isNotEmpty) {
        print("Primera devolución encontrada: ${devoluciones.first}");

        // Verificar estructura esperada
        final primeraDevolucion = devoluciones.first;
        if (primeraDevolucion['devo_Id'] != null) {
          print("ID de la primera devolución: ${primeraDevolucion['devo_Id']}");
        } else {
          print("ADVERTENCIA: La devolución no tiene un campo devo_Id");
          print("Claves disponibles: ${primeraDevolucion.keys.toList()}");
        }

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

        if (!algunaTieneId && devoluciones.length > 0) {
          print(
            "❌ ADVERTENCIA CRÍTICA: Ninguna devolución tiene un campo de ID reconocible.",
          );
          print(
            "Esto puede indicar un problema con el formato de los datos almacenados.",
          );
        }
      } else {
        print("⚠ No se encontraron devoluciones locales válidas");
      }

      return devoluciones;
    } catch (e) {
      print("❌ Error al obtener devoluciones locales: $e");
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");

      // Intento de recuperación de emergencia
      try {
        print("🔄 Intentando método alternativo de lectura...");
        final key = "json:$_archivoDevolucionesHistorial";
        final String? rawData = await _secureStorage.read(key: key);

        if (rawData != null && rawData.isNotEmpty) {
          print("Encontrados datos en bruto, intentando parseo manual...");

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

            print(
              "✓ Recuperadas ${devoluciones.length} devoluciones en modo de emergencia",
            );
            return devoluciones;
          }
        }

        print("❌ Recuperación de emergencia falló");
        return [];
      } catch (emergencyError) {
        print("❌ Error en recuperación de emergencia: $emergencyError");
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
        print("Modo ONLINE: Sincronizando devoluciones desde el servidor...");
        // Obtener devoluciones del servidor
        devoluciones = await sincronizarDevoluciones();

        // Guardar en almacenamiento local
        if (devoluciones.isNotEmpty) {
          print(
            "Guardando ${devoluciones.length} devoluciones en almacenamiento local",
          );
          await guardarDevolucionesHistorial(devoluciones);
          print("Devoluciones guardadas exitosamente en modo online");
        } else {
          print("No hay devoluciones para guardar en almacenamiento local");
        }

        // Si se solicita sincronización forzada de detalles
        if (forzarSincronizacionDetalles) {
          print(
            "Iniciando sincronización forzada de detalles para todas las devoluciones...",
          );
          try {
            await sincronizarDetallesDeTodasLasDevoluciones();
            print("Sincronización forzada de detalles completada exitosamente");
          } catch (e) {
            print("Error en la sincronización forzada de detalles: $e");
          }
        }
      } else {
        print("Modo OFFLINE: Cargando devoluciones desde almacenamiento local");
        // En modo offline, obtener directamente del almacenamiento local
        devoluciones = await obtenerDevolucionesLocal();
        print(
          "Se cargaron ${devoluciones.length} devoluciones desde almacenamiento local",
        );
      }

      return devoluciones;
    } catch (e) {
      print("Error al sincronizar y guardar devoluciones: $e");
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");

      // Intentar devolver lo que está guardado localmente
      try {
        final devolucionesLocales = await obtenerDevolucionesLocal();
        print(
          "Recuperadas ${devolucionesLocales.length} devoluciones locales después del error",
        );
        return devolucionesLocales;
      } catch (localError) {
        print("Error también al obtener devoluciones locales: $localError");
        return []; // Si todo falla, devolver lista vacía
      }
    }
  }

  /// Sincroniza y guarda los detalles de todas las devoluciones
  static Future<void> sincronizarDetallesDeTodasLasDevoluciones() async {
    try {
      print("Iniciando sincronización de detalles para todas las devoluciones");

      // Primero obtenemos todas las devoluciones
      final devoluciones = await obtenerDevolucionesLocal();
      if (devoluciones.isEmpty) {
        print("No hay devoluciones para sincronizar detalles");
        return;
      }

      print("Sincronizando detalles para ${devoluciones.length} devoluciones");

      // Para cada devolución, sincronizamos sus detalles
      int contadorExitosos = 0;
      int totalDetallesSincronizados = 0;

      // Procesar las devoluciones en bloques para no sobrecargar la memoria
      final int blockSize = 10; // Procesar 10 devoluciones a la vez

      for (int i = 0; i < devoluciones.length; i += blockSize) {
        final int fin = (i + blockSize < devoluciones.length)
            ? i + blockSize
            : devoluciones.length;
        print(
          "Procesando bloque de devoluciones ${i + 1} a $fin de ${devoluciones.length}",
        );

        // Imprimir progreso después de cada bloque
        print(
          "Progreso: $contadorExitosos/${devoluciones.length} devoluciones procesadas (${(contadorExitosos * 100 / devoluciones.length).toStringAsFixed(1)}%)",
        );
      }

      print(
        "Sincronización completa: $contadorExitosos/${devoluciones.length} devoluciones procesadas, $totalDetallesSincronizados detalles en total",
      );

      // Imprimir todos los IDs almacenados después de la sincronización
      await imprimirDetallesDevolucionesGuardados();
    } catch (e) {
      print("Error general en sincronizarDetallesDeTodasLasDevoluciones: $e");
    }
  }

  /// Convierte una lista de Maps a una lista de DevolucionesViewModel
  ///
  /// Esta función implementa una conversión robusta para manejar errores individuales
  /// y maximizar la cantidad de modelos que pueden ser convertidos correctamente.
  static List<DevolucionesViewModel> convertirAModelos(
    List<Map<String, dynamic>> devoluciones,
  ) {
    try {
      print("Convirtiendo ${devoluciones.length} devoluciones a modelos...");

      if (devoluciones.isEmpty) {
        print("Lista vacía, no hay nada que convertir");
        return [];
      }

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
          print("❌ Error al convertir devolución #$i: $e");

          // Mostrar información de diagnóstico sobre el objeto problemático
          try {
            final devolucion = devoluciones[i];
            print("Claves disponibles: ${devolucion.keys.toList()}");
            print(
              "Valores para diagnóstico: devo_Id=${devolucion['devo_Id']}, devoId=${devolucion['devoId']}, fecha=${devolucion['devo_Fecha'] ?? devolucion['devoFecha']}",
            );
          } catch (_) {
            print("No se pudo mostrar diagnóstico del objeto");
          }
        }
      }

      // Mostrar resumen de la conversión
      print(
        "✓ Convertidos ${modelos.length} de ${devoluciones.length} objetos a modelos (${errores} errores)",
      );
      return modelos;
    } catch (e) {
      print("❌ Error general al convertir devoluciones a modelos: $e");
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");
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
      print("Campo devo_Id corregido para devolución #$index");
    }

    // Verificar campo devo_Fecha / devoFecha
    if (!devolucion.containsKey('devo_Fecha') &&
        devolucion.containsKey('devoFecha')) {
      devolucion['devo_Fecha'] = devolucion['devoFecha'];
      print("Campo devo_Fecha corregido para devolución #$index");
    }

    // Verificar campo devo_Motivo / devoMotivo
    if (!devolucion.containsKey('devo_Motivo') &&
        devolucion.containsKey('devoMotivo')) {
      devolucion['devo_Motivo'] = devolucion['devoMotivo'];
      print("Campo devo_Motivo corregido para devolución #$index");
    }

    // Asegurar que los campos críticos existan (con valores por defecto si es necesario)
    if (!devolucion.containsKey('devo_Id') &&
        !devolucion.containsKey('devoId')) {
      print("⚠ ADVERTENCIA: Devolución #$index no tiene campo ID");
    }

    if (!devolucion.containsKey('devo_Fecha') &&
        !devolucion.containsKey('devoFecha')) {
      print("⚠ ADVERTENCIA: Devolución #$index no tiene campo fecha");
      // Asignar fecha actual como fallback
      devolucion['devo_Fecha'] = DateTime.now().toIso8601String();
    }

    // Convertir formato de fecha si es necesario
    final fechaValue = devolucion['devo_Fecha'] ?? devolucion['devoFecha'];
    if (fechaValue is String &&
        !fechaValue.contains('T') &&
        !fechaValue.contains(' ')) {
      print("⚠ Formato de fecha inválido para devolución #$index: $fechaValue");
      // Intentar convertir a formato ISO
      try {
        final DateTime fecha = DateTime.parse(fechaValue);
        devolucion['devo_Fecha'] = fecha.toIso8601String();
        print("✓ Fecha corregida a: ${devolucion['devo_Fecha']}");
      } catch (e) {
        print("❌ No se pudo corregir el formato de fecha: $e");
      }
    }
  }

  /// Imprime el contenido completo de devoluciones_detalles.json y los IDs presentes
  static Future<void> imprimirDetallesDevolucionesGuardados() async {
    try {
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);
      if (existingData == null || existingData.isEmpty) {
        print("[LOG] devoluciones_detalles.json está vacío o no existe");
        return;
      }
      final Map<String, dynamic> allDetalles = jsonDecode(existingData);
      print(
        "[LOG] IDs presentes en devoluciones_detalles.json: ${allDetalles.keys.toList()}",
      );

      // Contar cuántos detalles hay en total y por ID
      int totalDetalles = 0;
      Map<String, int> detallesPorId = {};

      allDetalles.forEach((key, value) {
        if (value is List) {
          int cantidadDetalles = value.length;
          detallesPorId[key] = cantidadDetalles;
          totalDetalles += cantidadDetalles;
        }
      });

      print("[LOG] Detalles por ID: $detallesPorId");
      print("[LOG] Total de detalles guardados: $totalDetalles");
    } catch (e) {
      print("[LOG] Error al imprimir devoluciones_detalles.json: $e");
    }
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
      print("Error al verificar si existen detalles para ID $devolucionId: $e");
      return false;
    }
  }

  /// Limpia completamente el almacenamiento local de detalles de devoluciones
  static Future<void> limpiarDetallesDevoluciones() async {
    try {
      final key = "json:$_archivoDetallesDevolucion";
      await _secureStorage.delete(key: key);
      print(
        "Almacenamiento local de detalles de devoluciones limpiado correctamente",
      );
    } catch (e) {
      print("Error al limpiar el almacenamiento de detalles: $e");
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
      print(
        "Sincronizando detalles de devolución ID: $devolucionId (Modo: ${isOnline ? 'Online' : 'Offline'})",
      );

      // Si no estamos online, vamos directamente al almacenamiento local
      if (!isOnline) {
        print(
          "Modo offline: Obteniendo detalles locales para ID $devolucionId",
        );
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false, // Forzar modo offline
        );
      }

      // Verificar si ya tenemos los detalles guardados localmente
      if (!forceSync) {
        final tieneDetalles = await existenDetallesParaDevolicion(devolucionId);
        if (tieneDetalles) {
          print(
            "Ya existen detalles locales para ID $devolucionId. Usando versión en caché.",
          );
          return await obtenerDetallesDevolucionLocal(
            devolucionId,
            isOnline: false, // No intentar sincronizar de nuevo
          );
        }
      }

      // Si no hay detalles locales o se fuerza la sincronización, obtenerlos del servidor
      print("Obteniendo detalles del servidor para ID $devolucionId");
      final detalles = await sincronizarDetallesDevolucion(devolucionId);

      // Verificar si realmente se obtuvieron detalles del servidor
      if (detalles.isEmpty) {
        print(
          "No se encontraron detalles en el servidor para ID $devolucionId",
        );

        // Intentar obtener los detalles locales como último recurso
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false, // No intentar sincronizar de nuevo
        );
      }

      // Si hay detalles, guardarlos localmente
      print(
        "Guardando ${detalles.length} detalles del servidor para ID $devolucionId",
      );

      // Antes de guardar, validar la estructura de los datos
      bool datosValidos = true;
      for (int i = 0; i < detalles.length; i++) {
        final detalle = detalles[i];
        if (!(detalle is Map)) {
          print(
            "⚠ ADVERTENCIA: Detalle #$i no es un mapa: ${detalle.runtimeType}",
          );
          datosValidos = false;
          break;
        }
      }

      if (!datosValidos) {
        print(
          "❌ Los datos recibidos del servidor no tienen la estructura esperada",
        );
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

      print(
        "✓ Procesados ${detallesMapSeguro.length} detalles para ID $devolucionId",
      );
      return detallesMapSeguro;
    } catch (e) {
      print(
        "❌ Error al sincronizar y guardar detalles de devolución ID $devolucionId: $e",
      );
      print("Stacktrace: ${e is Error ? e.stackTrace : ''}");

      // Intentar devolver lo que está guardado localmente como mecanismo de recuperación
      try {
        print(
          "🔄 Intentando recuperación de emergencia desde almacenamiento local...",
        );
        return await obtenerDetallesDevolucionLocal(
          devolucionId,
          isOnline: false, // No intentar sincronizar de nuevo
        );
      } catch (localError) {
        print("❌ Error también en la recuperación de emergencia: $localError");
        return []; // Devolver lista vacía si todo falla
      }
    }
  }

  /// Sincroniza los detalles de una devolución con el servidor
  static Future<List<dynamic>> sincronizarDetallesDevolucion(
    int devolucionId,
  ) async {
    try {
      print("Obteniendo detalles de devolución ID $devolucionId del servidor");
      final service = DevolucionesService();
      final detalles = await service.getDevolucionDetalles(devolucionId);

      // Verificar si la respuesta contiene datos
      if (detalles.isEmpty) {
        print(
          "El servidor devolvió 0 detalles para devolución ID $devolucionId",
        );
        return [];
      }

      // Convertir a formato Map para almacenamiento
      final detallesMap = detalles.map((detalle) => detalle.toJson()).toList();

      print(
        "Se sincronizaron ${detallesMap.length} detalles para la devolución ID $devolucionId",
      );

      // Mostrar un ejemplo de los datos para diagnóstico
      if (detallesMap.isNotEmpty) {
        print("Ejemplo de detalle sincronizado: ${detallesMap.first}");
      }

      return detallesMap;
    } catch (e) {
      print("Error al sincronizar detalles de devolución ID $devolucionId: $e");
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

      print(
        "Guardados ${detallesMapSeguro.length} detalles para devolución ID $devolucionId",
      );

      // Loggear el contenido completo después de guardar
      await imprimirDetallesDevolucionesGuardados();
    } catch (e) {
      print("Error al guardar detalles de devolución ID $devolucionId: $e");
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
      print(
        "Obteniendo detalles de devolución ID $devolucionId del almacenamiento local (Modo ${isOnline ? 'Online' : 'Offline'})",
      );
      // Loggear el contenido completo antes de leer
      await imprimirDetallesDevolucionesGuardados();
      final key = "json:$_archivoDetallesDevolucion";
      final String? existingData = await _secureStorage.read(key: key);

      if (existingData == null || existingData.isEmpty) {
        print("No hay datos de detalles almacenados localmente");

        // Solo intentar sincronizar si estamos online
        if (isOnline) {
          print(
            "Modo Online: Intentando sincronizar detalles para la devolución ID $devolucionId",
          );
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
            print("Error al intentar sincronizar detalles: $syncError");
            return [];
          }
        } else {
          print(
            "Modo Offline: No se pueden sincronizar detalles desde el servidor",
          );
          return [];
        }
      }

      // Obtenemos el mapa completo de detalles
      Map<String, dynamic> allDetalles = jsonDecode(existingData);

      // Obtenemos los detalles para esta devolución específica
      final detallesDevolucion = allDetalles[devolucionId.toString()];

      if (detallesDevolucion == null) {
        print(
          "No hay detalles almacenados para la devolución ID $devolucionId",
        );

        // Solo intentar sincronizar si estamos online
        if (isOnline) {
          print(
            "Modo Online: Intentando sincronizar detalles para la devolución ID $devolucionId",
          );
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
            print("Error al intentar sincronizar detalles: $syncError");
            return [];
          }
        } else {
          print(
            "Modo Offline: No se pueden sincronizar detalles desde el servidor",
          );
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
