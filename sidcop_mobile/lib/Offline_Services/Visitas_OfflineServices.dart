import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';

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
  static const String _archivoVisitasPendientes = 'visitas_pendientes.json';
  static const String _prefixImagenesVisita = 'imagenes_visita_';

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

      // Guardar los datos remotos en el archivo de historial
      // Importante: NO sobrescribir las visitas pendientes
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

  /// Método que obtiene tanto las visitas históricas como las pendientes.
  /// Util para presentar en la UI todas las visitas juntas.
  static Future<List<dynamic>> obtenerTodasLasVisitas() async {
    final historial = await obtenerVisitasHistorialLocal();
    final pendientes = await obtenerVisitasPendientesLocal();

    final resultado = List.from(historial);

    // Agregar las pendientes que no estén ya en el historial
    for (final p in pendientes) {
      if (p is! Map) continue;

      final signature = p['local_signature'];
      if (signature == null) {
        resultado.add(p);
        continue;
      }

      // Verificar que no exista ya en el historial
      final existe = historial.any(
        (h) => h is Map && h['local_signature'] == signature,
      );

      if (!existe) {
        resultado.add(p);
      }
    }

    print(
      'Total de visitas combinadas: ${resultado.length} (${historial.length} historial + ${pendientes.length} pendientes)',
    );
    return resultado;
  }

  /// Wrapper que fuerza lectura/sincronización remota para visitas (si se necesita).
  static Future<List<dynamic>> leerVisitasHistorial() async {
    return await sincronizarVisitasHistorial();
  }

  /// Agrega una visita localmente (carga, agrega y guarda).
  /// Evita duplicados calculando una "firma" basada en campos clave.
  /// Devuelve true si la visita fue añadida, false si ya existía.
  /// Lee las visitas pendientes almacenadas localmente o devuelve lista vacía.
  static Future<List<dynamic>> obtenerVisitasPendientesLocal() async {
    final raw = await leerJson(_archivoVisitasPendientes);
    if (raw == null) return [];
    return List.from(raw as List);
  }

  /// Guarda las visitas pendientes en un archivo separado.
  static Future<void> guardarVisitasPendientes(List<dynamic> visitas) async {
    await guardarJson(_archivoVisitasPendientes, visitas);
  }

  static Future<bool> agregarVisitaLocal(Map<String, dynamic> visita) async {
    // Registrar la estructura de la visita para depuración
    try {
      print('DEBUG - ESTRUCTURA DE VISITA OFFLINE A GUARDAR:');
      print(const JsonEncoder.withIndent('  ').convert(visita));
    } catch (e) {
      print('Error al imprimir estructura JSON: $e');
    }

    // Obtener las visitas pendientes almacenadas
    final lista = await obtenerVisitasPendientesLocal();

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

    // Asegurar que los campos críticos sean del tipo correcto
    visitaToSave['clie_Id'] = int.tryParse('${visitaToSave['clie_Id']}') ?? 0;
    visitaToSave['diCl_Id'] = int.tryParse('${visitaToSave['diCl_Id']}') ?? 0;
    visitaToSave['esVi_Id'] = int.tryParse('${visitaToSave['esVi_Id']}') ?? 0;
    // Siempre usar el ID 57 para el usuario de creación según requerimiento del SP
    visitaToSave['usua_Creacion'] = 57;

    lista.add(visitaToSave);
    await guardarVisitasPendientes(lista);

    // Mostrar la visita guardada para verificar
    print('\n===== VISITA OFFLINE GUARDADA CORRECTAMENTE =====');
    print('Cliente ID: ${visitaToSave['clie_Id']}');
    print('Dirección ID: ${visitaToSave['diCl_Id']}');
    print('Estado ID: ${visitaToSave['esVi_Id']}');
    print('Usuario Creación: ${visitaToSave['usua_Creacion']}');
    print('Firma local: ${visitaToSave['local_signature']}');
    print('\nDEBUG - VISITA GUARDADA CORRECTAMENTE:');
    print(const JsonEncoder.withIndent('  ').convert(visitaToSave));

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

      // Guardar los estados en almacenamiento local
      await guardarJson(_archivoEstadosVisita, data);

      try {
        final lista = List.from(data);
        print('SYNC: sincronizarEstadosVisita fetched ${lista.length} items');
      } catch (_) {
        print('SYNC: sincronizarEstadosVisita fetched (unknown count)');
      }

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

  /// Lee los estados de visita preferiendo el cache local. Si no hay datos
  /// locales, intenta sincronizar desde el servicio remoto y los guarda.
  /// Útil para poblar dropdowns: primero intenta usar lo ya descargado.
  static Future<List<Map<String, dynamic>>> leerEstadosVisita() async {
    final local = await obtenerEstadosVisitaLocal();
    if (local.isNotEmpty) return local;
    return await sincronizarEstadosVisita();
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
    final pendientes = await obtenerVisitasPendientesLocal();
    if (pendientes.isEmpty) return 0;

    // Imprimir todas las visitas offline para depuración
    print('DEBUG - VISITAS OFFLINE PENDIENTES: ${pendientes.length}');
    try {
      for (int i = 0; i < pendientes.length; i++) {
        print('VISITA OFFLINE #${i + 1}:');
        print(const JsonEncoder.withIndent('  ').convert(pendientes[i]));
      }
    } catch (e) {
      print('Error al imprimir visitas offline: $e');
    }

    final servicio = ClientesVisitaHistorialService();
    int sincronizadas = 0;

    // Copia de la lista para ir eliminando elementos sincronizados
    final remaining = List.from(pendientes);

    for (final p in pendientes) {
      try {
        final visita = Map<String, dynamic>.from(p as Map);

        final imagenesBase64 =
            (visita['imagenesBase64'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final diClId = int.tryParse('${visita['diCl_Id'] ?? 0}') ?? 0;
        final clieId = int.tryParse('${visita['clie_Id'] ?? 0}') ?? 0;

        final sig = (visita['local_signature'] ?? 'no-signature').toString();
        print(
          'SYNC: intentando subir visita local_signature=$sig clieId=$clieId diClId=$diClId imagenes=${imagenesBase64.length}',
        );

        try {
          // Construir payload para insertar la visita (reutilizamos la estructura local)
          final visitaPayload = Map<String, dynamic>.from(visita);

          // Verificar campos críticos antes de enviar
          print('\nDEBUG - VALIDACIÓN DE CAMPOS CRÍTICOS:');
          final camposCriticos = [
            'clie_Id',
            'diCl_Id',
            'clVi_Fecha',
            'esVi_Id',
            'clVi_Observaciones',
            'usua_Creacion',
          ];

          for (final campo in camposCriticos) {
            print('$campo: ${visitaPayload[campo]}');
          }

          // Limpiar campos locales/aux
          visitaPayload.remove('imagenesBase64');
          visitaPayload.remove('offline');
          visitaPayload.remove('local_signature');
          visitaPayload.remove('local_created_at');

          // Asegurar que tenemos un ID de usuario válido para la sincronización
          // Primero intentar obtener el usuario guardado en la visita
          int? usuarioGuardado;
          try {
            usuarioGuardado = int.tryParse('${visita['usua_Creacion'] ?? ''}');
          } catch (_) {
            usuarioGuardado = null;
          }

          // Asegurar que todos los campos numéricos sean números y no cadenas
          // Conversión explícita de los campos clave
          visitaPayload['clie_Id'] =
              int.tryParse('${visitaPayload['clie_Id']}') ?? 0;
          visitaPayload['diCl_Id'] =
              int.tryParse('${visitaPayload['diCl_Id']}') ?? 0;
          visitaPayload['esVi_Id'] =
              int.tryParse('${visitaPayload['esVi_Id']}') ?? 0;

          // Siempre usar el ID 57 para el usuario de creación según requerimiento del SP
          visitaPayload['usua_Creacion'] = 57;
          print('SYNC: usando usua_Creacion = 57 según requerimiento del SP');

          // Mostrar el payload final justo antes de enviarlo
          print('\nDEBUG - PAYLOAD FINAL ANTES DE ENVIAR:');
          print(const JsonEncoder.withIndent('  ').convert(visitaPayload));

          // Intentar crear la visita remoto usando el mismo flujo que la UI
          final insertResult = await servicio.insertarVisita(visitaPayload);

          // Try to obtain the created visit id using the same sequence the online UI uses:
          // 1) insertarVisita
          // 2) obtenerUltimaVisita
          int createdId = 0;
          try {
            final ultima = await servicio.obtenerUltimaVisita();
            if (ultima != null && ultima['clVi_Id'] != null) {
              createdId = int.tryParse('${ultima['clVi_Id']}') ?? 0;
            }
          } catch (_) {}

          // Fallback to any clVi_Id returned directly by insertarVisita
          if (createdId == 0) {
            createdId = int.tryParse('${insertResult['clVi_Id'] ?? 0}') ?? 0;
          }

          if (createdId > 0) {
            print(
              'SYNC: visita creada en remoto clVi_Id=$createdId local_signature=$sig',
            );

            // Determine the usuarioId to use when associating images: prefer the
            // user id that was sent (usua_Creacion) or fallback to globalVendId.
            int usuarioParaAsociar = 0;
            try {
              usuarioParaAsociar =
                  int.tryParse('${visitaPayload['usua_Creacion'] ?? ''}') ?? 0;
            } catch (_) {
              usuarioParaAsociar = 0;
            }
            if (usuarioParaAsociar <= 0) usuarioParaAsociar = globalVendId ?? 0;

            // Helper to extract an URL from upload response body in a tolerant way
            String _extractUrlFromUploadResponse(String body) {
              try {
                final parsed = jsonDecode(body);
                if (parsed is Map<String, dynamic>) {
                  // Common keys used by different backends
                  for (final candidate in ['ruta', 'url', 'data', 'result']) {
                    if (parsed.containsKey(candidate)) {
                      final val = parsed[candidate];
                      if (val is String && val.isNotEmpty) return val;
                      if (val is Map<String, dynamic>) {
                        // nested value
                        if (val['ruta'] != null) return val['ruta'].toString();
                        if (val['url'] != null) return val['url'].toString();
                      }
                    }
                  }
                } else if (parsed is String) {
                  return parsed;
                }
              } catch (_) {
                // not JSON, maybe plain text URL
                final trimmed = body.trim();
                if (trimmed.startsWith('http')) return trimmed;
              }
              return '';
            }

            // Subir y asociar im e1genes (si existen)
            int uploadedCount = 0;
            for (var i = 0; i < imagenesBase64.length; i++) {
              final base64str = imagenesBase64[i];
              try {
                final bytes = base64Decode(base64str);
                final uploadUrl = Uri.parse('$apiServer/Imagen/Subir');
                final req = http.MultipartRequest('POST', uploadUrl);
                req.headers['X-Api-Key'] = apikey;
                req.headers['accept'] = '*/*';
                final filename = 'visita_${sig}_$i.jpg';
                req.files.add(
                  http.MultipartFile.fromBytes(
                    'imagen',
                    bytes,
                    filename: filename,
                    contentType: MediaType('image', 'jpeg'),
                  ),
                );

                final streamedResp = await req.send();
                final respBody = await streamedResp.stream.bytesToString();
                if (streamedResp.statusCode == 200) {
                  try {
                    final rutaImagen = _extractUrlFromUploadResponse(respBody);
                    if (rutaImagen.isNotEmpty) {
                      final asociado = await servicio.asociarImagenAVisita(
                        visitaId: createdId,
                        imagenUrl: rutaImagen,
                        usuarioId: usuarioParaAsociar,
                      );
                      if (asociado) uploadedCount++;
                    } else {
                      print(
                        'SYNC ERROR: upload returned no image URL for visita $createdId body=$respBody',
                      );
                    }
                  } catch (e) {
                    print(
                      'SYNC ERROR: parsing upload response for visita $createdId: $e',
                    );
                  }
                } else {
                  print(
                    'SYNC ERROR: upload failed status=${streamedResp.statusCode} body=$respBody',
                  );
                }
              } catch (e, st) {
                print(
                  'SYNC ERROR: error uploading image #$i for visita local_signature=$sig: $e',
                );
                print(st);
              }
            }

            // Considerar sincronizada aunque algunas im e1genes hayan fallado en asociar
            try {
              remaining.removeWhere((item) {
                try {
                  return (item as Map)['local_signature'] ==
                      visita['local_signature'];
                } catch (_) {
                  return false;
                }
              });
            } catch (_) {}

            sincronizadas++;
            print(
              'SYNC: visita sincronizada y procesadas im e1genes=$uploadedCount local_signature=$sig',
            );
          } else {
            print(
              'SYNC ERROR: insertarVisita no devolvi\u00f3 clVi_Id para local_signature=$sig response=$insertResult',
            );
          }
        } catch (e, st) {
          // Log detallado para depuración cuando la API devuelve error
          try {
            print(
              'SYNC ERROR: fallo general al procesar visita local_signature=$sig',
            );
            print('SYNC ERROR: payload = ${visita.toString()}');
            print('SYNC ERROR: exception = $e');
            print('SYNC ERROR: stacktrace = $st');
          } catch (_) {}
          // conservar la visita para reintentos posteriores
        }
      } catch (e, st) {
        // Error al procesar la visita local (parsing/u otro). Loggear para investigar.
        try {
          print('SYNC ERROR: error procesando visita local: $e');
          print('SYNC ERROR: stacktrace = $st');
        } catch (_) {}
      }
    }

    // Guardar la lista restante (las no sincronizadas) en el archivo de pendientes
    await guardarVisitasPendientes(remaining);

    print(
      'DEBUG - VISITAS PENDIENTES DESPUÉS DE SINCRONIZAR: ${remaining.length}',
    );
    return sincronizadas;
  }

  /// Sincroniza toda la información relevante de visitas offline.
  static Future<void> sincronizarTodo() async {
    // Primero obtener las visitas pendientes para no perderlas
    final pendientes = await obtenerVisitasPendientesLocal();

    // Sincronizar datos del servidor
    final visitas = await sincronizarVisitasHistorial();
    await guardarVisitasHistorial(visitas);

    // Volver a guardar las pendientes para que no se pierdan
    if (pendientes.isNotEmpty) {
      print(
        'Preservando ${pendientes.length} visitas pendientes durante sincronización',
      );
      await guardarVisitasPendientes(pendientes);
    }

    final estados = await sincronizarEstadosVisita();
    await guardarJson(_archivoEstadosVisita, estados);
    final clientes = await sincronizarClientes();
    await guardarClientes(clientes);
    final direcciones = await sincronizarDirecciones();
    await guardarDirecciones(direcciones);
  }

  // ---------------------------------
  // Manejo de imágenes de visitas
  // ---------------------------------

  /// Genera la clave para almacenar las imágenes de una visita específica
  static String _claveImagenesVisita(int visitaId) {
    return 'json:${_prefixImagenesVisita}$visitaId';
  }

  /// Guarda las imágenes de una visita localmente
  /// @param visitaId ID de la visita
  /// @param imagenes Lista de imágenes en formato Map (como las devuelve la API)
  static Future<bool> guardarImagenesVisita(
    int visitaId,
    List<Map<String, dynamic>> imagenes,
  ) async {
    try {
      final clave = _claveImagenesVisita(visitaId);
      // Incluimos metadatos como la fecha de descarga
      final datosGuardar = {
        'visitaId': visitaId,
        'descargadoEl': DateTime.now().toIso8601String(),
        'imagenes': imagenes,
      };
      await _secureStorage.write(key: clave, value: jsonEncode(datosGuardar));
      print('✅ Guardadas ${imagenes.length} imágenes para visita $visitaId');
      return true;
    } catch (e) {
      print('❌ Error guardando imágenes para visita $visitaId: $e');
      return false;
    }
  }

  /// Obtiene las imágenes guardadas localmente para una visita
  /// @param visitaId ID de la visita
  /// @returns Lista de imágenes o null si no hay imágenes guardadas
  static Future<List<Map<String, dynamic>>?> obtenerImagenesVisitaLocal(
    int visitaId,
  ) async {
    try {
      final clave = _claveImagenesVisita(visitaId);
      final datosJson = await _secureStorage.read(key: clave);

      if (datosJson == null) {
        print('ℹ️ No hay imágenes guardadas para la visita $visitaId');
        return null;
      }

      final datos = jsonDecode(datosJson) as Map<String, dynamic>;
      final imagenes = List<Map<String, dynamic>>.from(
        datos['imagenes'] as List,
      );

      print(
        '✅ Recuperadas ${imagenes.length} imágenes locales para visita $visitaId',
      );
      return imagenes;
    } catch (e) {
      print('❌ Error recuperando imágenes para visita $visitaId: $e');
      return null;
    }
  }

  /// Descarga y guarda las imágenes de una visita desde el servidor
  /// @param visitaId ID de la visita
  /// @returns Lista de imágenes descargadas o null si hay error
  static Future<List<Map<String, dynamic>>?> sincronizarImagenesVisita(
    int visitaId,
  ) async {
    try {
      print('🔄 Sincronizando imágenes para visita $visitaId...');
      final servicio = ClientesVisitaHistorialService();
      final imagenes = await servicio.listarImagenesPorVisita(visitaId);

      if (imagenes.isNotEmpty) {
        // Procesamos las URLs para guardar también las imágenes como archivos
        // y así poder mostrarlas sin conexión
        final baseUrl = 'http://200.59.27.115:8091'; // URL base del servidor
        final imagenesConRutasLocales = <Map<String, dynamic>>[];

        for (var i = 0; i < imagenes.length; i++) {
          final imagen = Map<String, dynamic>.from(imagenes[i]);
          final imagenUrl = imagen['imVi_Imagen'] as String?;

          if (imagenUrl != null && imagenUrl.isNotEmpty) {
            final urlCompleta = "$baseUrl$imagenUrl";
            final nombreArchivo = 'visita_${visitaId}_img_$i.jpg';

            try {
              // Intentar descargar la imagen y guardarla localmente
              final rutaLocal = await guardarArchivoDesdeUrl(
                urlCompleta,
                nombreArchivo,
              );

              if (rutaLocal != null) {
                imagen['ruta_local'] = rutaLocal;
                print('✅ Imagen $i guardada localmente en $rutaLocal');
              }
            } catch (e) {
              print('⚠️ Error descargando imagen $i: $e');
              // Continuar con las demás imágenes si falla una
            }
          }

          imagenesConRutasLocales.add(imagen);
        }

        // Guardar los metadatos de las imágenes en secure storage
        await guardarImagenesVisita(visitaId, imagenesConRutasLocales);

        print(
          '✅ Sincronizadas ${imagenesConRutasLocales.length} imágenes para visita $visitaId',
        );
        return imagenesConRutasLocales;
      } else {
        print('ℹ️ No hay imágenes para la visita $visitaId');
        // Guardar un registro vacío para no tener que consultar de nuevo
        await guardarImagenesVisita(visitaId, []);
        return [];
      }
    } catch (e) {
      print('❌ Error sincronizando imágenes para visita $visitaId: $e');
      return null;
    }
  }

  /// Obtiene las imágenes de una visita, primero intenta local, luego remoto si hay conexión
  /// @param visitaId ID de la visita
  /// @param forzarSincronizacion Si es true, siempre intenta sincronizar desde el servidor
  /// @returns Lista de imágenes o lista vacía si no hay imágenes
  static Future<List<Map<String, dynamic>>> obtenerImagenesVisita(
    int visitaId, {
    bool forzarSincronizacion = false,
  }) async {
    // Primero intentamos obtener las imágenes guardadas localmente
    final imagenesLocales = await obtenerImagenesVisitaLocal(visitaId);

    // Si no hay imágenes locales o se fuerza la sincronización, intentamos obtener del servidor
    if (imagenesLocales == null || forzarSincronizacion) {
      try {
        // Verificar conexión usando VerificarService
        final isOnline = await VerificarService.verificarConexion();

        if (isOnline) {
          final imagenesRemoto = await sincronizarImagenesVisita(visitaId);
          if (imagenesRemoto != null && imagenesRemoto.isNotEmpty) {
            return imagenesRemoto;
          }
        } else if (imagenesLocales != null) {
          // Si no hay conexión pero tenemos imágenes locales, las usamos
          print(
            'ℹ️ Sin conexión, usando imágenes locales para visita $visitaId',
          );
          return imagenesLocales;
        }
      } catch (e) {
        print('⚠️ Error en obtenerImagenesVisita: $e');
        // Si hay error y tenemos imágenes locales, las devolvemos
        if (imagenesLocales != null) return imagenesLocales;
      }
    } else if (imagenesLocales.isNotEmpty) {
      // Si hay imágenes locales y no se fuerza sincronización, las devolvemos
      return imagenesLocales;
    }

    // Si llegamos aquí, no hay imágenes o hubo error
    return [];
  }
}
