import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';

/// Servicio offline para operaciones relacionadas con el historial de visitas.
class VisitasOffline {
  // Carpeta raíz dentro de documents para los archivos offline
  static const String _carpetaOffline = 'offline';

  // Instancia de secure storage para valores pequeños/medianos
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo`.
  /// Escritura atómica: se guarda el JSON como string en secure storage bajo la clave 'json:<nombreArchivo>'.
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      final key = 'json:$nombreArchivo';
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
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

  /// Guarda bytes en secure storage como base64 bajo la clave 'bin:<nombreArchivo>'.
  static Future<void> guardarBytes(
    String nombreArchivo,
    Uint8List bytes,
  ) async {
    try {
      final key = 'bin:$nombreArchivo';
      final encoded = base64Encode(bytes);
      await _secureStorage.write(key: key, value: encoded);
    } catch (e) {
      rethrow;
    }
  }

  /// Lee bytes desde secure storage (preferido) o desde disco si existe.
  /// Devuelve null si no existe.
  static Future<Uint8List?> leerBytes(String nombreArchivo) async {
    try {
      final key = 'bin:$nombreArchivo';
      try {
        final s = await _secureStorage.read(key: key);
        if (s != null) {
          final decoded = base64Decode(s);
          return Uint8List.fromList(decoded);
        }
      } catch (_) {}

      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (!await archivo.exists()) return null;
      final bytes = await archivo.readAsBytes();
      return Uint8List.fromList(bytes);
    } catch (e) {
      rethrow;
    }
  }

  /// Comprueba si un archivo existe en secure storage o en disco.
  static Future<bool> existe(String nombreArchivo) async {
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

  /// Borra un archivo (json o bin) si existe.
  static Future<void> borrar(String nombreArchivo) async {
    try {
      if (nombreArchivo.toLowerCase().endsWith('.json')) {
        final key = 'json:$nombreArchivo';
        await _secureStorage.delete(key: key);
        return;
      }
      final binKey = 'bin:$nombreArchivo';
      final existing = await _secureStorage.read(key: binKey);
      if (existing != null) {
        await _secureStorage.delete(key: binKey);
        return;
      }
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Lista los nombres de archivos dentro de la carpeta offline (no recursivo)
  /// y añade keys guardadas en secure storage.
  static Future<List<String>> listarArchivos() async {
    final archivos = <String>[];
    final docs = await _directorioDocuments();
    final carpeta = Directory(p.join(docs.path, _carpetaOffline));
    if (await carpeta.exists()) {
      final items = carpeta.listSync();
      for (final it in items) {
        if (it is File) archivos.add(p.basename(it.path));
      }
    }
    try {
      final all = await _secureStorage.readAll();
      for (final k in all.keys) {
        if (k.startsWith('json:')) {
          archivos.add(k.replaceFirst('json:', ''));
        } else if (k.startsWith('bin:')) {
          archivos.add(k.replaceFirst('bin:', ''));
        }
      }
    } catch (_) {}
    return archivos;
  }

  /// Guarda un JSON en secure storage bajo la clave `key`.
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
  // Helpers específicos para Visitas
  // -----------------------------
  static const String _archivoVisitas = 'visitas_historial.json';

  /// Sincroniza el historial de visitas desde el servicio remoto y guarda localmente.
  static Future<List<dynamic>> sincronizarVisitasHistorial() async {
    try {
      final servicio = ClientesVisitaHistorialService();
      final data = await servicio.listar();
      try {
        final lista = List.from(data);
        print(
          'SYNC: sincronizarVisitasHistorial fetched ${lista.length} items',
        );
      } catch (_) {
        print('SYNC: sincronizarVisitasHistorial fetched (unknown count)');
      }
      await guardarJson(_archivoVisitas, data);
      return data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda manualmente una lista de visitas en el almacenamiento local.
  static Future<void> guardarVisitasHistorial(List<dynamic> visitas) async {
    await guardarJson(_archivoVisitas, visitas);
  }

  /// Lee el historial de visitas almacenado localmente o devuelve lista vacía.
  static Future<List<dynamic>> obtenerVisitasHistorialLocal() async {
    final raw = await leerJson(_archivoVisitas);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Wrapper que fuerza lectura/sincronización remota para visitas (si se necesita).
  static Future<List<dynamic>> leerVisitasHistorial() async {
    return await sincronizarVisitasHistorial();
  }

  /// Agrega una visita localmente (carga, agrega y guarda).
  /// Evita duplicados calculando una "firma" basada en campos clave.
  /// Devuelve true si la visita fue añadida, false si ya existía.
  static Future<bool> agregarVisitaLocal(Map<String, dynamic> visita) async {
    final lista = await obtenerVisitasHistorialLocal();

    // Calcular firma a partir de campos clave que definen una visita
    final signatureSource = {
      'clie_Id': visita['clie_Id'] ?? visita['clieId'] ?? 0,
      'diCl_Id': visita['diCl_Id'] ?? visita['diClId'] ?? 0,
      'clVi_Fecha': visita['clVi_Fecha'] ?? '',
      'esVi_Id': visita['esVi_Id'] ?? 0,
      'clVi_Observaciones': visita['clVi_Observaciones'] ?? '',
    };
    final signature = jsonEncode(signatureSource);

    // Comprobar si ya existe la misma firma
    for (final item in lista) {
      try {
        if (item is Map && item['local_signature'] == signature) {
          // Ya existe una visita con la misma firma -> no duplicar
          return false;
        }
      } catch (_) {
        // ignorar elementos malformados
      }
    }

    // Añadir metadata local y guardar
    final visitaToSave = Map<String, dynamic>.from(visita);
    visitaToSave['local_signature'] = signature;
    visitaToSave['local_created_at'] = DateTime.now().toIso8601String();

    lista.add(visitaToSave);
    await guardarVisitasHistorial(lista);
    return true;
  }

  // -----------------------------
  // Dropdowns / listas auxiliares (estados, clientes, direcciones)
  // -----------------------------
  static const String _archivoClientes = 'clientes.json';
  static const String _archivoDirecciones = 'direcciones.json';
  static const String _archivoEstadosVisita = 'estados_visita.json';

  /// Sincroniza y guarda los estados de visita (EstadoVisita/Listar)
  static Future<List<Map<String, dynamic>>> sincronizarEstadosVisita() async {
    try {
      final servicio = ClientesVisitaHistorialService();
      final data = await servicio.obtenerEstadosVisita();
      try {
        final lista = List.from(data);
        print('SYNC: sincronizarEstadosVisita fetched ${lista.length} items');
      } catch (_) {
        print('SYNC: sincronizarEstadosVisita fetched (unknown count)');
      }
      await guardarJson(_archivoEstadosVisita, data);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza y guarda los clientes visibles para el vendedor.
  static Future<List<Map<String, dynamic>>> sincronizarClientes() async {
    try {
      final servicio = ClientesVisitaHistorialService();
      final data = await servicio.obtenerClientesPorVendedor();
      try {
        final lista = List.from(data);
        print('SYNC: sincronizarClientes fetched ${lista.length} items');
      } catch (_) {
        print('SYNC: sincronizarClientes fetched (unknown count)');
      }
      await guardarJson(_archivoClientes, data);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Sincroniza direcciones para todos los clientes del vendedor y las guarda.
  /// Nota: esto realiza una llamada por cliente (paralelizada) usando el servicio existente.
  static Future<List<dynamic>> sincronizarDirecciones() async {
    try {
      final servicio = ClientesVisitaHistorialService();
      final clientes = await servicio.obtenerClientesPorVendedor();
      final futures = clientes.map((c) {
        final id = c['clie_Id'] is int
            ? c['clie_Id'] as int
            : int.tryParse('${c['clie_Id']}') ?? 0;
        return servicio.obtenerDireccionesPorCliente(id);
      }).toList();
      final results = await Future.wait(futures);
      final direcciones = results.expand((l) => l).toList();
      try {
        print(
          'SYNC: sincronizarDirecciones fetched ${direcciones.length} items',
        );
      } catch (_) {}
      await guardarJson(_archivoDirecciones, direcciones);
      return direcciones;
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda manualmente una lista de clientes localmente.
  static Future<void> guardarClientes(
    List<Map<String, dynamic>> clientes,
  ) async {
    await guardarJson(_archivoClientes, clientes);
  }

  /// Lee clientes locales o devuelve lista vacía.
  static Future<List<Map<String, dynamic>>> obtenerClientesLocal() async {
    final raw = await leerJson(_archivoClientes);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  /// Guarda manualmente la lista de direcciones localmente.
  static Future<void> guardarDirecciones(List<dynamic> direcciones) async {
    await guardarJson(_archivoDirecciones, direcciones);
  }

  /// Lee direcciones locales o devuelve lista vacía.
  static Future<List<dynamic>> obtenerDireccionesLocal() async {
    final raw = await leerJson(_archivoDirecciones);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Lee estados de visita locales o devuelve lista vacía.
  static Future<List<Map<String, dynamic>>> obtenerEstadosVisitaLocal() async {
    final raw = await leerJson(_archivoEstadosVisita);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (_) {
      return [];
    }
  }

  /// Devuelve la ruta absoluta en Documents para un nombre de archivo simple.
  static Future<String> rutaEnDocuments(String nombreArchivo) async {
    final docs = await _directorioDocuments();
    return p.join(docs.path, nombreArchivo);
  }

  /// Descarga y guarda un archivo (por ejemplo imagen) en Documents.
  static Future<String?> guardarArchivoDesdeUrl(
    String url,
    String nombreArchivo,
  ) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final ruta = await rutaEnDocuments(nombreArchivo);
        final file = File(ruta);
        await file.writeAsBytes(resp.bodyBytes);
        return ruta;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Sincroniza las visitas pendientes que fueron guardadas en modo offline.
  /// Para cada visita con `offline == true` intenta subirla usando el servicio
  /// remoto (crearVisitaConImagenes). Si la subida es exitosa, la visita se elimina
  /// del almacen local. Retorna la cantidad de visitas sincronizadas correctamente.
  static Future<int> sincronizarPendientes() async {
    final lista = await obtenerVisitasHistorialLocal();
    if (lista.isEmpty) return 0;

    final pendientes = lista
        .where((v) => v is Map && (v['offline'] == true))
        .toList();
    if (pendientes.isEmpty) return 0;

    final servicio = ClientesVisitaHistorialService();
    int sincronizadas = 0;

    // Copia de la lista para ir eliminando elementos sincronizados
    final remaining = List.from(lista);

    for (final p in pendientes) {
      try {
        final visita = Map<String, dynamic>.from(p as Map);

        final imagenesBase64 =
            (visita['imagenesBase64'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final diClId = int.tryParse('${visita['diCl_Id'] ?? 0}') ?? 0;
        final veRuId = int.tryParse('${visita['veRu_Id'] ?? 0}') ?? 0;
        final clieId = int.tryParse('${visita['clie_Id'] ?? 0}') ?? 0;
        final esViId = int.tryParse('${visita['esVi_Id'] ?? 0}') ?? 0;
        final clViObservaciones = visita['clVi_Observaciones'] ?? '';

        DateTime clViFecha;
        try {
          clViFecha = DateTime.parse(
            visita['clVi_Fecha'] ?? DateTime.now().toIso8601String(),
          );
        } catch (_) {
          clViFecha = DateTime.now();
        }

        // Intentar crear la visita con imágenes
        await servicio.crearVisitaConImagenes(
          diClId: diClId,
          veRuId: veRuId,
          clieId: clieId,
          esViId: esViId,
          clViObservaciones: clViObservaciones,
          clViFecha: clViFecha,
          imagenesBase64: imagenesBase64,
        );

        // Si no lanzó excepción, consideramos sincronizado: eliminar de la lista local
        try {
          remaining.removeWhere((item) {
            try {
              return item is Map &&
                  item['local_signature'] == visita['local_signature'];
            } catch (_) {
              return false;
            }
          });
        } catch (_) {}

        sincronizadas++;
      } catch (e) {
        // Ignorar error por visita y continuar con las demás
        // Podríamos agregar logging aquí si se requiere.
      }
    }

    // Guardar la lista restante (las no sincronizadas)
    await guardarVisitasHistorial(remaining);
    return sincronizadas;
  }
}
