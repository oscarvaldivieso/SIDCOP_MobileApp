// Archivo para manejar clientes en modo offline
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/DropdownDataService.dart';
import 'package:sidcop_mobile/services/cloudinary_service.dart';

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
      if (!hasConnection) return;

      final dropdownService = DropdownDataService();
      final imageUploadService = ImageUploadService();
      final noSincronizados = <Map<String, dynamic>>[];

      for (var cliente in pendientes) {
        try {
          String? imageUrl;
          final imageKey = cliente['imageKey'] as String?;
          
          // Si hay una imagen guardada, subirla primero
          if (imageKey != null) {
            print('Buscando imagen con key: $imageKey');
            final imageData = await _secureStorage.read(key: imageKey);
            if (imageData != null && imageData.isNotEmpty) {
              print('Imagen encontrada, subiendo...');
              final imageBytes = base64Decode(imageData);
              imageUrl = await imageUploadService.uploadImageFromBytes(imageBytes);
              print('Imagen subida exitosamente: $imageUrl');
              
              // Asignar la URL de la imagen al campo correcto
              cliente['clie_ImagenDelNegocio'] = imageUrl;
              
              // Eliminar la imagen del almacenamiento local
              await _secureStorage.delete(key: imageKey);
              print('Imagen eliminada del almacenamiento local');
              cliente.remove('imageKey');
            }
          }

          print('Enviando datos del cliente al servidor...');
          
          // Crear una copia del cliente sin los campos que no necesita el servidor
          final clienteParaEnviar = Map<String, dynamic>.from(cliente);
          clienteParaEnviar.remove('direcciones');
          
          // Asegurarse de que clie_ImagenDelNegocio esté presente
          if (!clienteParaEnviar.containsKey('clie_ImagenDelNegocio')) {
            clienteParaEnviar['clie_ImagenDelNegocio'] = '';
          }
          
          print('Datos del cliente a enviar: $clienteParaEnviar');
          
          // Enviar los datos del cliente al servidor
          final response = await dropdownService.insertCliente(clienteParaEnviar);
          print('Respuesta del servidor: $response');

          if (response['success'] == true) {
            print('Cliente sincronizado exitosamente');
          } else {
            print('Error al sincronizar cliente: ${response['message']}');
            noSincronizados.add(cliente);
          }
        } catch (e) {
          print('Error al sincronizar cliente: $e');
          noSincronizados.add(cliente);
        }
      }

      // Guardar los clientes que no se pudieron sincronizar
      await guardarClientesPendientes(noSincronizados);
    } catch (e) {
      print('Error en sincronizarClientesPendientes: $e');
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
}