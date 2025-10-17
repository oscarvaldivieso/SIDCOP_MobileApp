import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/VendedoresService.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';

/// Servicios para operaciones offline: guardar/leer JSON y archivos binarios.

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//RUTAS SCREEN TY RUTAS DETAILS
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class RutasScreenOffline {
  // Carpeta raíz dentro de documents para los archivos offline
  static const String _carpetaOffline = 'offline';
  // Devuelve el directorio de documents
  static Future<Directory> _directorioDocuments() async {
    return await getApplicationDocumentsDirectory();
  }

  // Construye la ruta absoluta para un archivo relativo dentro de la carpeta offline
  static Future<String> _rutaArchivo(String nombreRelativo) async {
    final docs = await _directorioDocuments();
    final ruta = p.join(docs.path, _carpetaOffline, nombreRelativo);
    final dirPadre = Directory(p.dirname(ruta));
    if (!await dirPadre.exists()) {
      await dirPadre.create(recursive: true);
    }
    return ruta;
  }

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo` (por ejemplo: 'clientes.json').
  /// La escritura es atómica: escribe en un temporal y renombra.
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      // Guardar JSON en almacenamiento seguro (clave 'json:<nombreArchivo>').
      // Usamos secure storage porque el requerimiento es que todos los JSON se guarden allí.
      final contenido = jsonEncode(objeto);
      final key = 'json:$nombreArchivo';
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      // Si falla, lanzar la excepción para que el llamador la maneje
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = 'json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda bytes en un archivo (por ejemplo imágenes, mbtiles). Escritura atómica.
  static Future<void> guardarBytes(
    String nombreArchivo,
    Uint8List bytes,
  ) async {
    try {
      // Guardar bytes en secure storage como base64 (fallback) y también
      // escribir un archivo en disco dentro de la carpeta 'offline' para
      // que consumidores que esperan ruta/archivo local funcionen offline.
      final key = 'bin:$nombreArchivo';
      final encoded = base64Encode(bytes);
      await _secureStorage.write(key: key, value: encoded);

      // Escribir a disco de forma atómica: escribir en un temporal y renombrar.
      try {
        final ruta = await _rutaArchivo(nombreArchivo);
        final targetFile = File(ruta);
        final tempPath = '$ruta.tmp';
        final tempFile = File(tempPath);
        // Asegurar que el directorio padre existe ( _rutaArchivo ya lo crea )
        await tempFile.writeAsBytes(bytes, flush: true);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(ruta);
      } catch (e) {
        // No abortar todo el proceso si la escritura a disco falla; ya tenemos
        // la copia en secure storage. Loguear para diagnóstico.
        //print('WARN: guardarBytes fallo al escribir en disco: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Lee bytes desde un archivo. Devuelve null si no existe.
  static Future<Uint8List?> leerBytes(String nombreArchivo) async {
    try {
      // Intentar leer desde disco primero (mejor rendimiento y compatibilidad
      // con consumidores que esperan archivos locales). Si no existe en disco,
      // intentar leer desde secure storage.
      final ruta = await _rutaArchivo(nombreArchivo);
      try {
        final archivo = File(ruta);
        if (await archivo.exists()) {
          final bytes = await archivo.readAsBytes();
          return Uint8List.fromList(bytes);
        }
      } catch (_) {
        // si fallo leyendo disco, seguir con secure storage
      }

      // Fallback: leer desde secure storage
      final key = 'bin:$nombreArchivo';
      try {
        final s = await _secureStorage.read(key: key);
        if (s != null) {
          final decoded = base64Decode(s);
          // Escribir una copia en disco para futuros accesos rápidos
          try {
            final rutaSave = await _rutaArchivo(nombreArchivo);
            final archivoSave = File(rutaSave);
            if (!await archivoSave.exists()) {
              await archivoSave.writeAsBytes(decoded, flush: true);
            }
          } catch (_) {}
          return Uint8List.fromList(decoded);
        }
      } catch (_) {}
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Comprueba si un archivo existe en la carpeta offline.
  static Future<bool> existe(String nombreArchivo) async {
    // Comprobar secure storage (json o bin) y disco
    if (nombreArchivo.toLowerCase().endsWith('.json')) {
      final key = 'json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s != null) return true;
    }
    final binKey = 'bin:$nombreArchivo';
    final b = await _secureStorage.read(key: binKey);
    if (b != null) return true;
    final ruta = await _rutaArchivo(nombreArchivo);
    final archivo = File(ruta);
    return archivo.exists();
  }

  /// Borra un archivo si existe.
  static Future<void> borrar(String nombreArchivo) async {
    try {
      if (nombreArchivo.toLowerCase().endsWith('.json')) {
        final key = 'json:$nombreArchivo';
        await _secureStorage.delete(key: key);
        return;
      }
      // Intentar borrar binario en secure storage
      final binKey = 'bin:$nombreArchivo';
      final existing = await _secureStorage.read(key: binKey);
      if (existing != null) {
        await _secureStorage.delete(key: binKey);
        return;
      }
      // Si no estaba en secure storage, borrar archivo en disco
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Lista los nombres de archivos dentro de la carpeta offline (no recursivo).
  static Future<List<String>> listarArchivos() async {
    // Listar archivos en carpeta offline + JSON almacenados en secure storage
    final archivos = <String>[];
    final docs = await _directorioDocuments();
    final carpeta = Directory(p.join(docs.path, _carpetaOffline));
    if (await carpeta.exists()) {
      final items = carpeta.listSync();
      for (final it in items) {
        if (it is File) archivos.add(p.basename(it.path));
      }
    }
    // Añadir keys guardadas en secure storage (prefijo 'json:' y 'bin:')
    try {
      final all = await _secureStorage.readAll();
      for (final k in all.keys) {
        if (k.startsWith('json:')) {
          archivos.add(k.replaceFirst('json:', ''));
        } else if (k.startsWith('bin:')) {
          archivos.add(k.replaceFirst('bin:', ''));
        }
      }
    } catch (_) {
      // ignorar problemas con secure storage en el listado
    }
    return archivos;
  }

  // Funciones de conveniencia para clientes (json en 'clientes.json')
  static const String _archivoClientes = 'clientes.json';

  static Future<void> guardarClientes(
    List<Map<String, dynamic>> clientes,
  ) async {
    await guardarJson(_archivoClientes, clientes);
  }

  static Future<List<Map<String, dynamic>>> cargarClientes() async {
    final raw = await leerJson(_archivoClientes);
    if (raw == null) return [];
    try {
      // Asegurar lista de mapas
      final lista = List<Map<String, dynamic>>.from(raw as List);
      return lista;
    } catch (e) {
      return [];
    }
  }

  // Instancia de secure storage para valores sensibles (pequeños/medianos)
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Guarda un objeto JSON (serializable) en el almacenamiento seguro bajo la clave `key`.
  /// Nota: secure storage está pensado para strings pequeños/medianos. No usar para archivos muy grandes.
  static Future<void> guardarJsonSeguro(String key, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      rethrow;
    }
  }

  /// Lee y decodifica un JSON almacenado en secure storage bajo `key`. Devuelve null si no existe.
  static Future<dynamic> leerJsonSeguro(String key) async {
    try {
      final s = await _secureStorage.read(key: key);
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      rethrow;
    }
  }

  // -----------------------------
  // Helpers específicos para 'details' de ruta
  // -----------------------------
  /// Guarda los detalles de una ruta en secure storage bajo la clave 'details_ruta_<id>'
  // Detalles de ruta: funcionalidad removida intencionalmente.
  // Se conserva la firma como stub para evitar romper llamadas externas.
  static Future<void> guardarDetallesRuta(
    int rutaId,
    Map<String, dynamic> detalles,
  ) async {
    try {
      final key = 'details_ruta_$rutaId';
      await guardarJsonSeguro(key, detalles);
    } catch (e) {
      // No interrumpir el flujo de sincronización si falla el guardado local
      //print('WARN: guardarDetallesRuta failed for ruta $rutaId: $e');
    }
  }

  /// Lee los detalles de una ruta desde secure storage; devuelve null si no existe
  static Future<Map<String, dynamic>?> leerDetallesRuta(int rutaId) async {
    try {
      // Primero intentar leer detalles específicos por ruta (si fueron guardados antes)
      final key = 'details_ruta_$rutaId';
      final detallesRaw = await leerJsonSeguro(key);

      List<Map<String, dynamic>> clientesJson = [];
      List<Map<String, dynamic>> direccionesJson = [];
      String? staticMapUrl;
      String? staticMapLocalPath;

      if (detallesRaw != null) {
        // Aceptar estructuras flexibles
        try {
          clientesJson = List<Map<String, dynamic>>.from(
            detallesRaw['clientes'] as List? ?? [],
          );
        } catch (_) {
          clientesJson = [];
        }
        try {
          direccionesJson = List<Map<String, dynamic>>.from(
            detallesRaw['direcciones'] as List? ?? [],
          );
        } catch (_) {
          direccionesJson = [];
        }

        // Si los datos guardados tienen 0 direcciones, borrarlos y usar fallback
        if (direccionesJson.isEmpty) {
        
          await borrarDetallesRuta(rutaId);
          // Usar fallback inmediatamente
          clientesJson = await cargarClientes();
          final rawDirs = await obtenerDireccionesLocal();
        
          try {
            direccionesJson = List<Map<String, dynamic>>.from(rawDirs);
          } catch (_) {
            direccionesJson = [];
          }
        }

        staticMapUrl = detallesRaw['staticMapUrl']?.toString();
        staticMapLocalPath = detallesRaw['staticMapLocalPath']?.toString();
      } else {
     
        // Fallback: usar los JSON locales sincronizados (clientes.json / direcciones.json)
        clientesJson = await cargarClientes();
        final rawDirs = await obtenerDireccionesLocal();
       
        try {
          direccionesJson = List<Map<String, dynamic>>.from(rawDirs);
        } catch (_) {
          // Si no se puede convertir, dejar vacío
          direccionesJson = [];
        }
        // si existe imagen local para la ruta, devolver su path
        try {
          final localPath = await rutaEnDocuments('map_static_$rutaId.png');
          final f = File(localPath);
          if (await f.exists()) staticMapLocalPath = localPath;
        } catch (_) {}
      }

      // Aplicar filtrado: clientes por ruta_Id, direcciones por clie_id
      final clientesFiltrados = clientesJson
          .where((c) => (c['ruta_Id'] ?? c['rutaId']) == rutaId)
          .toList();

      final clienteIds = clientesFiltrados
          .map((c) => c['clie_Id'] ?? c['clieId'] ?? c['id'])
          .where((id) => id != null)
          .toSet();

      final direccionesFiltradas = direccionesJson
          .where(
            (d) => clienteIds.contains(
              d['clie_id'] ??
                  d['clieId'] ??
                  d['clie_Id'] ??
                  d['clieId'] ??
                  d['clieId'],
            ),
          )
          .toList();

      // Normalizar claves para asegurar compatibilidad con fromJson de los modelos
      List<Map<String, dynamic>> clientesNorm = clientesFiltrados.map((c) {
        final map = Map<String, dynamic>.from(c as Map);
        return {
          'clie_Id': map['clie_Id'] ?? map['clieId'] ?? map['id'],
          'clie_Codigo':
              map['clie_Codigo'] ?? map['clieCodigo'] ?? map['codigo'],
          'clie_Nombres':
              map['clie_Nombres'] ?? map['nombre'] ?? map['clieNombres'],
          'clie_Apellidos':
              map['clie_Apellidos'] ?? map['apellidos'] ?? map['clieApellidos'],
          'clie_NombreNegocio':
              map['clie_NombreNegocio'] ??
              map['nombreNegocio'] ??
              map['negocio'],
          'clie_ImagenDelNegocio':
              map['clie_ImagenDelNegocio'] ?? map['imagen'] ?? map['foto'],
          'clie_DireccionExacta':
              map['clie_DireccionExacta'] ??
              map['direccionExacta'] ??
              map['direccion'],
          'ruta_Id': map['ruta_Id'] ?? map['rutaId'] ?? map['ruta'],
          // Passthrough: incluir cualquier key adicional para que fromJson pueda usarla
          ...map,
        };
      }).toList();

      List<Map<String, dynamic>> direccionesNorm = direccionesFiltradas.map((
        d,
      ) {
        final map = Map<String, dynamic>.from(d as Map);
        // Helper para obtener valor original (convirtiendo tipos simples a lo esperado)
        dynamic get(List<String> keys) {
          for (final k in keys) {
            if (map.containsKey(k) && map[k] != null) return map[k];
          }
          return null;
        }

        return {
          'diCl_Id': get(['diCl_Id', 'diClId', 'dicl_id', 'diclId', 'id']),
          'clie_Id': get(['clie_Id', 'clieId', 'clie_id']),
          'colo_Id': get(['colo_Id', 'coloId']),
          'diCl_DireccionExacta': get([
            'diCl_DireccionExacta',
            'diCl_Direccion',
            'dicl_direccionexacta',
            'direccion',
          ]),
          'diCl_Observaciones': get([
            'diCl_Observaciones',
            'dicl_observaciones',
            'observaciones',
          ]),
          'diCl_Latitud': get([
            'diCl_Latitud',
            'dicl_latitud',
            'latitud',
            'diclLatitud',
          ]),
          'diCl_Longitud': get([
            'diCl_Longitud',
            'dicl_longitud',
            'longitud',
            'diclLongitud',
          ]),
          'muni_Descripcion': get([
            'muni_Descripcion',
            'muni_descripcion',
            'muniDescripcion',
          ]),
          'depa_Descripcion': get([
            'depa_Descripcion',
            'depa_descripcion',
            'depaDescripcion',
          ]),
          'usua_Creacion': get(['usua_Creacion', 'usua_creacion']),
          'diCl_FechaCreacion': get([
            'diCl_FechaCreacion',
            'diCl_Fecha',
            'dicl_fechacreacion',
          ]),
          'usua_Modificacion': get(['usua_Modificacion', 'usua_modificacion']),
          'diCl_FechaModificacion': get([
            'diCl_FechaModificacion',
            'diCl_FechaMod',
            'dicl_fechamodificacion',
          ]),
          // copiar campos del cliente si están presentes
          'clie_Nombres': get(['clie_Nombres', 'clieNombres', 'nombre']),
          'clie_Apellidos': get(['clie_Apellidos', 'apellido', 'apellidos']),
          'clie_NombreNegocio': get([
            'clie_NombreNegocio',
            'negocio',
            'nombreNegocio',
          ]),
          'clie_Codigo': get(['clie_Codigo', 'clieCodigo', 'codigo']),
          // Passthrough de resto
          ...map,
        };
      }).toList();

      return {
        'clientes': clientesNorm,
        'direcciones': direccionesNorm,
        'staticMapUrl': staticMapUrl,
        'staticMapLocalPath': staticMapLocalPath,
      };
    } catch (e) {
      // en caso de fallo, devolver null para que el llamador tome la ruta online
      return null;
    }
  }

  /// Borra los detalles de una ruta de secure storage (si existen)
  static Future<void> borrarDetallesRuta(int rutaId) async {
    try {
      final key = 'details_ruta_$rutaId';
      await _secureStorage.delete(key: key);
    } catch (e) {
      //print('WARN: borrarDetallesRuta failed for ruta $rutaId: $e');
    }
  }

  /// Borra todos los detalles de rutas guardados para forzar regeneración
  static Future<void> limpiarTodosLosDetalles() async {
    try {
      final allKeys = await _secureStorage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('details_ruta_')) {
          await _secureStorage.delete(key: key);
          //print('DEBUG: deleted obsolete key: $key');
        }
      }
      //print('DEBUG: limpiarTodosLosDetalles completed');
    } catch (e) {
      //print('WARN: limpiarTodosLosDetalles failed: $e');
    }
  }

  /// Devuelve la ruta absoluta en Documents para un nombre de archivo simple
  /// (no usa la carpeta 'offline'). Esto replica el comportamiento de
  /// `guardarImagenDeMapaStatic` en `Rutas_mapscreen.dart` que guarda en
  /// Documents directamente.
  static Future<String> rutaEnDocuments(String nombreArchivo) async {
    final docs = await _directorioDocuments();
    return p.join(docs.path, nombreArchivo);
  }

  /// Descarga una imagen desde `imageUrl` y la guarda en Documents con el
  /// nombre `nombreArchivo.png`. Devuelve la ruta del archivo guardado o
  /// null si ocurrió un error. Replica el comportamiento de
  /// `guardarImagenDeMapaStatic` en `Rutas_mapscreen.dart`.
  static Future<String?> guardarImagenDeMapaStatic(
    String imageUrl,
    String nombreArchivo,
  ) async {
    // Per requirement: offline service must not download or call remote static
    // map endpoints. Image caching must be handled by the UI while online.
    // Keep a placeholder implementation for legacy callers.
    return null;
  }

  // -----------------------------
  // Métodos de sincronización con los endpoints usados en pantalla 'Rutas'
  // Estos métodos consultan los servicios remotos y almacenan la copia
  // local utilizando las funciones anteriores (guardarJson).
  // -----------------------------

  /// Sincroniza las rutas desde el endpoint y las guarda en 'rutas.json'.
  static Future<List<dynamic>> sincronizarRutas() async {
    try {
      final servicio = RutasService();
      final data = await servicio.getRutas();
      // Log para diagnosticar respuesta remota
      try {
        final lista = List.from(data);
        //print('SYNC: sincronizarRutas fetched ${lista.length} items');
      } catch (_) {
        //print('SYNC: sincronizarRutas fetched (unknown count)');
      }
      // Guardar la respuesta tal cual (normalmente es List)
      await guardarJson('rutas.json', data);
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza los clientes desde el endpoint y los guarda en 'clientes.json'.
  static Future<List<Map<String, dynamic>>> sincronizarClientes() async {
    try {
      final servicio = ClientesService();
      final data = await servicio.getClientes();
      try {
        final lista = List.from(data);
        //print('SYNC: sincronizarClientes fetched ${lista.length} items');
      } catch (_) {
        //print('SYNC: sincronizarClientes fetched (unknown count)');
      }
      await guardarJson(_archivoClientes, data);
      // After saving clients JSON, attempt to download and cache business images
      try {
        for (final c in data) {
          try {
            if (c is! Map) continue;
            final id = (c['clie_Id'] ?? c['clieId'] ?? c['id'])?.toString();
            if (id == null || id.isEmpty) continue;
            // Support several possible image keys
            final imageUrl =
                (c['clie_ImagenDelNegocio'] ??
                        c['clieImagenDelNegocio'] ??
                        c['imagen'] ??
                        c['foto'] ??
                        '')
                    ?.toString() ??
                '';
            if (imageUrl.isEmpty) continue;
            final filename = 'foto_negocio_${id}.jpg';
            final exists = await existe(filename);
            if (exists) continue; // skip if already stored
            try {
              final resp = await http
                  .get(Uri.parse(imageUrl))
                  .timeout(const Duration(seconds: 8));
              if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                await guardarBytes(
                  filename,
                  Uint8List.fromList(resp.bodyBytes),
                );
                //print('SYNC: saved negocio image for cliente $id -> $filename');
              } else {
                // ignore non-200
              }
            } catch (_) {
              // Ignore download failures per-client to avoid aborting sync
            }
          } catch (_) {
            continue;
          }
        }
      } catch (_) {}
      // Intentar convertir a lista de mapas
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda la foto de negocio de un cliente (nombre: 'foto_negocio_<clienteId>.jpg').
  static Future<void> guardarFotoNegocio(
    String clienteId,
    Uint8List bytes,
  ) async {
    final filename = 'foto_negocio_${clienteId}.jpg';
    await guardarBytes(filename, bytes);
  }

  /// Lee la foto de negocio de un cliente si existe.
  static Future<Uint8List?> leerFotoNegocio(String clienteId) async {
    final filename = 'foto_negocio_${clienteId}.jpg';
    return await leerBytes(filename);
  }

  /// Devuelve la ruta absoluta en disco del archivo de foto del negocio si
  /// existe, o null si no está disponible en disco. Esto es útil para
  /// widgets que prefieren `Image.file(File(path))`.
  static Future<String?> rutaFotoNegocioLocal(String clienteId) async {
    final filename = 'foto_negocio_${clienteId}.jpg';
    try {
      final ruta = await _rutaArchivo(filename);
      final archivo = File(ruta);
      if (await archivo.exists()) return ruta;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sincroniza las direcciones de clientes y las guarda en 'direcciones.json'.
  static Future<List<dynamic>> sincronizarDirecciones() async {
    try {
      //print('DEBUG: sincronizarDirecciones - starting...');
      final servicio = DireccionClienteService();
      final data = await servicio.getDireccionesPorCliente();
      
      try {
        final lista = List.from(data);
        //print('SYNC: sincronizarDirecciones fetched ${lista.length} items');
        if (lista.isNotEmpty) {
        
        }
      } catch (_) {
        //print('SYNC: sincronizarDirecciones fetched (unknown count)');
      }

      // Convertir objetos DireccionCliente a JSON maps antes de guardar
      List<Map<String, dynamic>> direccionesJson = [];
      for (final item in data) {
        direccionesJson.add(item.toJson());
      }

    
      await guardarJson('direcciones.json', direccionesJson);
      //print('DEBUG: sincronizarDirecciones - saved to direcciones.json');
      return direccionesJson;
    } catch (e) {
      //print('ERROR: sincronizarDirecciones failed: $e');
      rethrow;
    }
  }

  /// Sincroniza el historial de visitas (ClientesVisitaHistorialService.listar)
  /// y lo guarda en 'visitas_historial.json'.
  static Future<List<dynamic>> sincronizarVisitasHistorial() async {
    try {
      final servicio = ClientesVisitaHistorialService();
      final data = await servicio.listarPorVendedor();
      try {
        final lista = List.from(data);
      
      } catch (_) {
        //print('SYNC: sincronizarVisitasHistorial fetched (unknown count)');
      }
      await guardarJson('visitas_historial.json', data);
      return data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda manualmente una lista de visitas en el almacenamiento local (secure storage).
  static Future<void> guardarVisitasHistorial(List<dynamic> visitas) async {
    await guardarJson('visitas_historial.json', visitas);
  }

  /// Lee el historial de visitas almacenado localmente o devuelve lista vacía.
  static Future<List<dynamic>> obtenerVisitasHistorialLocal() async {
    final raw = await leerJson('visitas_historial.json');
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Wrapper que fuerza lectura/sincronización remota para visitas (si se necesita).
  static Future<List<dynamic>> leerVisitasHistorial() async {
    return await sincronizarVisitasHistorial();
  }

  /// Sincroniza vendedores_por_rutas (VendedoresService.listarPorRutas) y guarda en 'vendedores_por_rutas.json'.
  static Future<List<dynamic>> sincronizarVendedoresPorRutas() async {
    try {
      final servicio = VendedoresService();
      final data = await servicio.listarPorRutas();
      try {
        final lista = List.from(data);
  
      } catch (_) {
        //print('SYNC: sincronizarVendedoresPorRutas fetched (unknown count)');
      }

      // Convertir objetos VendedoresPorRutaModel a JSON
      final vendedoresJson = <Map<String, dynamic>>[];
      for (final item in data) {
        vendedoresJson.add(item.toJson());
      }


      await guardarJson('vendedores_por_rutas.json', vendedoresJson);
      return vendedoresJson;
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda manualmente la estructura de vendedores por rutas.
  static Future<void> guardarVendedoresPorRutas(List<dynamic> datos) async {
    await guardarJson('vendedores_por_rutas.json', datos);
  }

  /// Lee vendedores por rutas desde almacenamiento local.
  static Future<List<dynamic>> obtenerVendedoresPorRutasLocal() async {
    final raw = await leerJson('vendedores_por_rutas.json');
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Wrapper para forzar lectura remota
  static Future<List<dynamic>> leerVendedoresPorRutas() async {
    return await sincronizarVendedoresPorRutas();
  }

  /// Sincroniza la lista de vendedores (útil para filtros/permisos) y la guarda en 'vendedores.json'.
  static Future<List<dynamic>> sincronizarVendedores() async {
    try {
      final servicio = VendedoresService();
      final data = await servicio.listar();
      try {
        final lista = List.from(data);
        //print('SYNC: sincronizarVendedores fetched ${lista.length} items');
      } catch (_) {
        //print('SYNC: sincronizarVendedores fetched (unknown count)');
      }
      await guardarJson('vendedores.json', data);
      return data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza Rutas, Clientes, Direcciones y Vendedores en paralelo y devuelve
  /// un mapa con los resultados. Si alguna falla, la excepción se propaga.
  static Future<Map<String, dynamic>> sincronizarRutas_Todo() async {
    try {
      final results = await Future.wait([
        sincronizarRutas(),
        sincronizarClientes(),
        sincronizarDirecciones(),
        sincronizarVisitasHistorial(),
        sincronizarVendedores(),
      ]);
      try {
  
      
      } catch (_) {
        //print('SYNC: sincronizarRutas_Todo results sizes unknown');
      }
      return {
        'rutas': results[0],
        'clientes': results[1],
        'direcciones': results[2],
        'vendedores': results[3],
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Genera y guarda los detalles (clientes, direcciones, mapa estático) para
  /// todas las rutas disponibles. Usa datos locales si existen, o sincroniza
  /// las rutas remotas si no hay datos locales.
  static Future<void> guardarDetallesTodasRutas({bool forzar = false}) async {
    try {
      // Obtener rutas locales; si no hay, sincronizar desde remoto
      List<dynamic> rutas = await obtenerRutasLocal();
      if (rutas.isEmpty) {
        rutas = await sincronizarRutas();
      }

      // Traer (y sincronizar) clientes y direcciones una sola vez.
      // Usar las funciones sincronizar* para asegurar que las imágenes de negocio
      // se descarguen y guarden en el offline store.
      final List<dynamic> clientesRaw = await sincronizarClientes();
      final List<dynamic> direccionesRaw = await sincronizarDirecciones();

      for (final r in rutas) {
        try {
          // soportar objetos Map o formatos ya convertidos
          final rutaId = (r is Map) ? r['ruta_Id'] ?? r['rutaId'] : null;
          if (rutaId == null) continue;

          // filtrar clientes por ruta
          final clientesFiltrados = clientesRaw
              .where((c) => (c is Map ? c['ruta_Id'] : null) == rutaId)
              .toList();

          final clienteIds = clientesFiltrados
              .map((c) => (c is Map ? c['clie_Id'] : null))
              .where((id) => id != null)
              .toSet();

          final direccionesFiltradas = direccionesRaw
              .where((d) => clienteIds.contains(d is Map ? d['clie_id'] : null))
              .toList();

          // Construir lista de puntos visibles por si se necesita la URL
          final visiblePoints = direccionesFiltradas
              .where(
                (d) =>
                    (d is Map ? d['dicl_latitud'] : null) != null &&
                    (d is Map ? d['dicl_longitud'] : null) != null,
              )
              .map((d) => '${d['dicl_latitud']},${d['dicl_longitud']}')
              .join('|');

          // Construir una URL informativa (no la usaremos para descargar)
          final staticUrl =
              'https://maps.googleapis.com/maps/api/staticmap?size=400x150&visible=$visiblePoints&key=$mapApikey';

          // NO descargar desde Google Static Maps aquí. Usar la imagen que
          // ya fue generada por `Rutas_screen` y guardada en Documents.
          final localPath = await rutaEnDocuments('map_static_$rutaId.png');
          final localFile = File(localPath);
          final hasLocal = await localFile.exists();
          if (hasLocal) {
          
          } else {
        
          }

          // Construir detalles y guardarlos (incluye referencia local si existe)
          final detalles = {
            'clientes': clientesFiltrados
                .map((c) => c is Map ? c : {})
                .toList(),
            'direcciones': direccionesFiltradas
                .map((d) => d is Map ? d : {})
                .toList(),
            'staticMapUrl': staticUrl,
            'staticMapLocalPath': hasLocal ? localPath : null,
          };
          await guardarDetallesRuta(rutaId, detalles);
        } catch (_) {
          // continuar con la siguiente ruta si falla una
          continue;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // -----------------------------
  // Métodos de lectura con los archivos de Rutas
  // -----------------------------
  /// Devuelve las rutas almacenadas localmente (rutas.json) o lista vacía.
  static Future<List<dynamic>> obtenerRutasLocal() async {
    final raw = await RutasScreenOffline.leerJson('rutas.json');
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Fuerza sincronización remota y devuelve los datos.
  static Future<List<dynamic>> leerRutas() async {
    return await RutasScreenOffline.leerRutas();
  }

  /// Clientes locales (clientes.json)
  static Future<List<Map<String, dynamic>>> obtenerClientesLocal() async {
    final raw = await RutasScreenOffline.leerJson(
      RutasScreenOffline._archivoClientes,
    );
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  static Future<List<Map<String, dynamic>>> leerClientes() async {
    return await RutasScreenOffline.leerClientes();
  }

  /// Direcciones locales
  static Future<List<dynamic>> obtenerDireccionesLocal() async {
    final raw = await RutasScreenOffline.leerJson('direcciones.json');
    if (raw == null) return [];
    return List.from(raw as List);
  }

  static Future<List<dynamic>> leerDirecciones() async {
    return await RutasScreenOffline.leerDirecciones();
  }

  /// Vendedores locales
  static Future<List<dynamic>> obtenerVendedoresLocal() async {
    final raw = await RutasScreenOffline.leerJson('vendedores.json');
    if (raw == null) return [];
    return List.from(raw as List);
  }

  static Future<List<dynamic>> leerVendedores() async {
    return await RutasScreenOffline.leerVendedores();
  }

  /// Sincroniza toda la información relevante de rutas offline.
  static Future<void> sincronizarTodo() async {
    final rutas = await sincronizarRutas();
    final clientes = await sincronizarClientes();
    final direcciones = await sincronizarDirecciones();
    final vendedores = await sincronizarVendedores();
    await guardarClientes(List<Map<String, dynamic>>.from(clientes));
    await guardarJson('direcciones.json', direcciones);
    await guardarJson('vendedores.json', vendedores);
    await guardarJson('rutas.json', rutas);
    await sincronizarVisitasHistorial();
    await sincronizarVendedoresPorRutas();
  }
}
