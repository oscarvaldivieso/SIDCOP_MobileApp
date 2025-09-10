// Archivo para manejar clientes en modo offline
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/DropdownDataService.dart';
import 'package:sidcop_mobile/services/cloudinary_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';

class ClientesOfflineService {
  static const String _archivoClientes = 'clientes.json';
  static const String _archivoClientesPendientes = 'clientes_pendientes.json';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Guarda clientes en un archivo JSON
  static Future<void> guardarClientes(List<Map<String, dynamic>> clientes) async {
    await guardarJson(_archivoClientes, clientes);
  }

  /// Carga clientes desde un archivo JSON
  static Future<List<Map<String, dynamic>>> cargarClientes() async {
    final raw = await leerJson(_archivoClientes);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Guarda clientes pendientes en un archivo JSON
  static Future<void> guardarClientesPendientes(List<Map<String, dynamic>> clientes) async {
    await guardarJson(_archivoClientesPendientes, clientes);
  }

  /// Carga clientes pendientes desde un archivo JSON
  static Future<List<Map<String, dynamic>>> cargarClientesPendientes() async {
    final raw = await leerJson(_archivoClientesPendientes);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      return [];
    }
  }

  /// Sincroniza clientes pendientes con el servidor
  static Future<void> sincronizarClientesPendientes() async {
    try {
      final pendientes = await cargarClientesPendientes();
      if (pendientes.isEmpty) return;

      final hasConnection = await SyncService.hasInternetConnection();
      if (!hasConnection) {
        print('No hay conexión a internet. Sincronización pospuesta.');
        return;
      }

      final dropdownService = DropdownDataService();
      final imageUploadService = ImageUploadService();
      final noSincronizados = <Map<String, dynamic>>[];

      for (final cliente in pendientes) {
        try {
          String? imageUrl;
          final imageKey = cliente['imageKey'] as String?;
          final direcciones = (cliente['direcciones'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

          // Subir imagen si existe
          if (imageKey != null) {
            print('Buscando imagen con key: $imageKey');
            final imageData = await _secureStorage.read(key: imageKey);
            if (imageData != null && imageData.isNotEmpty) {
              print('Imagen encontrada, subiendo...');
              final imageBytes = base64Decode(imageData);
              imageUrl = await imageUploadService.uploadImageFromBytes(imageBytes);
              print('Imagen subida exitosamente: $imageUrl');
              cliente['clie_ImagenDelNegocio'] = imageUrl;
              await _secureStorage.delete(key: imageKey);
              cliente.remove('imageKey');
            }
          }

          // Crear cliente en el servidor
          print('Enviando datos del cliente al servidor...');
          final clienteParaEnviar = Map<String, dynamic>.from(cliente);
          clienteParaEnviar.remove('direcciones'); // Remover direcciones antes de enviar
          final response = await dropdownService.insertCliente(clienteParaEnviar);

          if (response['success'] == true) {
            final clientId = response['data']?['data'] is String
                ? int.tryParse(response['data']['data'])
                : (response['data']?['data'] as num?)?.toInt();

            if (clientId != null) {
              print('✅ ID del cliente creado: $clientId');

              // Sincronizar direcciones
              int successfulAddresses = 0;
              for (var direccion in direcciones) {
                try {
                  direccion['clie_Id'] = clientId;
                  print('Enviando dirección: ${jsonEncode(direccion)}');
                  final direccionObj = DireccionCliente.fromJson(direccion);
                  final result = await DireccionClienteService().insertDireccionCliente(direccionObj);

                  if (result['success'] == true) {
                    successfulAddresses++;
                    print('✅ Dirección guardada exitosamente');
                  } else {
                    print('❌ Error al guardar dirección: ${result['message']}');
                  }
                } catch (e) {
                  print('❌ Excepción al sincronizar dirección: $e');
                }
              }

              print('Resumen de sincronización de direcciones: $successfulAddresses/${direcciones.length} direcciones sincronizadas correctamente');
            } else {
              print('❌ No se pudo obtener el ID del cliente de la respuesta');
              noSincronizados.add(cliente);
            }
          } else {
            print('❌ Error al sincronizar cliente: ${response['message']}');
            noSincronizados.add(cliente);
          }
        } catch (e) {
          print('❌ Error al sincronizar cliente: $e');
          noSincronizados.add(cliente);
        }
      }

      // Guardar los clientes que no se pudieron sincronizar
      await guardarClientesPendientes(noSincronizados);
    } catch (e) {
      print('❌ Error en sincronizarClientesPendientes: $e');
      rethrow;
    }
  }

  /// Guarda un objeto JSON en almacenamiento seguro
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    final contenido = jsonEncode(objeto);
    await _secureStorage.write(key: nombreArchivo, value: contenido);
  }

  /// Lee un objeto JSON desde almacenamiento seguro
  static Future<dynamic> leerJson(String nombreArchivo) async {
    final contenido = await _secureStorage.read(key: nombreArchivo);
    if (contenido == null) return null;
    return jsonDecode(contenido);
  }

  /// Guarda el detalle de un cliente en almacenamiento local
  static Future<void> guardarDetalleCliente(Map<String, dynamic> cliente) async {
    final clientes = await cargarClientes();
    final index = clientes.indexWhere((c) => c['clie_Id'] == cliente['clie_Id']);

    if (index != -1) {
      clientes[index] = cliente;
    } else {
      clientes.add(cliente);
    }

    await guardarClientes(clientes);
  }

  /// Carga el detalle de un cliente desde almacenamiento local
  static Future<Map<String, dynamic>?> cargarDetalleCliente(int clienteId) async {
    final clientes = await cargarClientes();
    final cliente = clientes.firstWhere(
      (c) => c['clie_Id'] == clienteId,
      orElse: () => <String, dynamic>{},
    );
    return cliente.isNotEmpty ? cliente : null;
  }

  /// Guarda las colonias en almacenamiento local
  static Future<void> guardarColonias(List<Map<String, dynamic>> colonias) async {
    await guardarJson('colonias.json', colonias);
  }

  /// Carga las colonias desde almacenamiento local
  static Future<List<Map<String, dynamic>>> cargarColonias() async {
    final raw = await leerJson('colonias.json');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw);
    } catch (e) {
      return [];
    }
  }

  /// Maneja la carga de colonias considerando el modo offline
  static Future<List<Map<String, dynamic>>> manejarColoniasOffline(Future<List<Map<String, dynamic>>> Function() fetchColoniasOnline) async {
    final hasConnection = await SyncService.hasInternetConnection();

    if (hasConnection) {
      try {
        final colonias = await fetchColoniasOnline();
        await guardarColonias(colonias);
        return colonias;
      } catch (e) {
        print('Error al cargar colonias en línea: $e');
      }
    }

    // Si no hay conexión o falla la carga en línea, cargar desde almacenamiento local
    return await cargarColonias();
  }

  /// Guarda un cliente y sus direcciones en modo offline
  static Future<void> saveClienteOffline(
    Map<String, dynamic> cliente,
    List<Map<String, dynamic>> direcciones, {
    Uint8List? imageBytes,
  }) async {
    try {
      // Guardar la imagen en el almacenamiento seguro si se proporciona
      String? imageKey;
      if (imageBytes != null) {
        imageKey = 'cliente_image_${DateTime.now().millisecondsSinceEpoch}';
        await _secureStorage.write(
          key: imageKey,
          value: base64Encode(imageBytes),
        );
        print('Imagen guardada con key: $imageKey');
      }

      // Crear una copia del cliente para modificar
      final clienteParaGuardar = Map<String, dynamic>.from(cliente);
      
      // Agregar la key de la imagen si existe
      if (imageKey != null) {
        clienteParaGuardar['imageKey'] = imageKey;
      }
      
      // Agregar las direcciones al cliente
      clienteParaGuardar['direcciones'] = direcciones;
      
      // Cargar clientes pendientes existentes
      final pendientes = await cargarClientesPendientes();
      
      // Agregar el nuevo cliente
      pendientes.add(clienteParaGuardar);
      
      // Guardar la lista actualizada
      await guardarClientesPendientes(pendientes);
      
      print('Cliente guardado offline exitosamente');
    } catch (e) {
      print('Error al guardar cliente offline: $e');
      rethrow;
    }
  }

  /// Obtiene direcciones de cliente con enfoque offline-first (como inventory)
  static Future<List<dynamic>> getDireccionesClienteOfflineFirst(int clienteId) async {
    try {
      print('🏠 Cargando direcciones offline-first para cliente: $clienteId');
      
      // 1. SIEMPRE cargar desde cache primero (como inventory)
      final direccionesCache = await _getOfflineDireccionesDataSafe(clienteId);
      
      // 2. Si hay datos en cache, devolverlos inmediatamente
      if (direccionesCache.isNotEmpty) {
        print('✅ Direcciones encontradas en cache: ${direccionesCache.length}');
        
        // 3. Sincronizar en background si hay conexión (sin bloquear UI)
        _syncDireccionesInBackground(clienteId);
        
        return direccionesCache;
      }
      
      // 4. Si no hay cache, intentar cargar desde servidor
      print('📡 No hay cache, intentando cargar desde servidor...');
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        try {
          final clientesService = ClientesService();
          final direcciones = await clientesService.getDireccionesCliente(clienteId);
          
          if (direcciones.isNotEmpty) {
            // Guardar en cache para futuras consultas
            await _saveDireccionesCache(clienteId, direcciones);
            print('✅ Direcciones cargadas desde servidor y guardadas en cache: ${direcciones.length}');
            return direcciones;
          }
        } catch (e) {
          print('❌ Error cargando desde servidor: $e');
        }
      }
      
      print('⚠️ No se pudieron cargar direcciones');
      return [];
    } catch (e) {
      print('❌ Error en getDireccionesClienteOfflineFirst: $e');
      return [];
    }
  }

  /// Lee datos de direcciones de manera segura (sin lanzar excepciones)
  static Future<List<dynamic>> _getOfflineDireccionesDataSafe(int clienteId) async {
    try {
      final cacheKey = 'direcciones_cliente_$clienteId';
      final raw = await leerJson(cacheKey);
      if (raw != null && raw is List) {
        return List<dynamic>.from(raw);
      }
      return [];
    } catch (e) {
      print('Error leyendo direcciones offline: $e');
      return [];
    }
  }

  /// Sincroniza direcciones en background sin bloquear UI
  static void _syncDireccionesInBackground(int clienteId) {
    // Ejecutar en background sin await para no bloquear
    () async {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        final bool isOnline = connectivityResult != ConnectivityResult.none;
        
        if (isOnline) {
          final clientesService = ClientesService();
          final direcciones = await clientesService.getDireccionesCliente(clienteId);
          
          if (direcciones.isNotEmpty) {
            await _saveDireccionesCache(clienteId, direcciones);
            print('🔄 Direcciones sincronizadas en background para cliente: $clienteId');
          }
        }
      } catch (e) {
        print('Error en sincronización background de direcciones: $e');
      }
    }();
  }

  /// Guarda direcciones en cache
  static Future<void> _saveDireccionesCache(int clienteId, List<dynamic> direcciones) async {
    try {
      final cacheKey = 'direcciones_cliente_$clienteId';
      await guardarJson(cacheKey, direcciones);
    } catch (e) {
      print('Error guardando direcciones en cache: $e');
    }
  }

  /// Sincroniza direcciones para todos los clientes durante el login
  static Future<void> syncDireccionesForAllClients(List<dynamic> clientes) async {
    try {
      print('🔄 Iniciando sincronización de direcciones para todos los clientes...');
      final clientesService = ClientesService();
      
      for (final cliente in clientes) {
        try {
          final clienteId = cliente['clie_Id'] as int?;
          if (clienteId != null) {
            final direcciones = await clientesService.getDireccionesCliente(clienteId);
            if (direcciones.isNotEmpty) {
              await _saveDireccionesCache(clienteId, direcciones);
              print('✅ Direcciones sincronizadas para cliente: $clienteId');
            }
          }
        } catch (e) {
          print('Error sincronizando direcciones para cliente: $e');
          continue;
        }
      }
      print('🎉 Sincronización de direcciones completada');
    } catch (e) {
      print('Error en syncDireccionesForAllClients: $e');
    }
  }

  /// Verifica si hay datos de direcciones offline disponibles
  static Future<bool> hasOfflineDireccionesData(int clienteId) async {
    try {
      final direcciones = await _getOfflineDireccionesDataSafe(clienteId);
      return direcciones.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}