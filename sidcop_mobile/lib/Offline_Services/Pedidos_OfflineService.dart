import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.dart';

class PedidosOfflineService {
  // Carpeta raíz dentro de documents para los archivos offline
  static const String _carpetaOffline = 'offline';
  static const _secureStorage = FlutterSecureStorage();

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

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo`
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      final key = 'json:pedidos_$nombreArchivo';
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = 'json:pedidos_$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      rethrow;
    }
  }

  /// Guarda un nuevo pedido localmente cuando no hay conexión
  static Future<void> guardarPedidoPendiente(PedidosViewModel pedido) async {
    try {
      // Leer pedidos pendientes existentes
      final pedidos = await obtenerPedidosPendientes();
      
      // Asignar un ID temporal negativo para identificar como pendiente
      pedido.pediId = -1 * (pedidos.length + 1);
      pedido.estado = 'Pendiente';
      
      // Agregar el nuevo pedido
      pedidos.add(pedido);
      
      // Guardar la lista actualizada
      await guardarJson('pedidos_pendientes.json', 
          pedidos.map((p) => p.toJson()).toList());
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene todos los pedidos pendientes de sincronización
  static Future<List<PedidosViewModel>> obtenerPedidosPendientes() async {
    try {
      final data = await leerJson('pedidos_pendientes.json');
      if (data == null) return [];
      
      return (data as List)
          .map((json) => PedidosViewModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Sincroniza los pedidos pendientes con el servidor
  static Future<int> sincronizarPedidosPendientes() async {
    try {
      final pedidosPendientes = await obtenerPedidosPendientes();
      if (pedidosPendientes.isEmpty) return 0;

      final pedidosService = PedidosService();
      int exitosos = 0;

      for (final pedido in pedidosPendientes) {
        try {
          // Intentar enviar el pedido al servidor
          final resultado = await pedidosService.crearPedido(pedido);
          
          if (resultado) {
            exitosos++;
          }
        } catch (e) {
          print('Error sincronizando pedido ${pedido.pediId}: $e');
          // Continuar con el siguiente pedido si falla uno
          continue;
        }
      }

      // Si todos los pedidos se sincronizaron correctamente, limpiar la lista
      if (exitosos == pedidosPendientes.length) {
        await guardarJson('pedidos_pendientes.json', []);
      }

      return exitosos;
    } catch (e) {
      print('Error en sincronizarPedidosPendientes: $e');
      rethrow;
    }
  }

  /// Obtiene los pedidos, ya sea del servidor o del almacenamiento local
  static Future<List<PedidosViewModel>> obtenerPedidos() async {
    try {
      // Primero intentar obtener del servidor
      final perfilService = PerfilUsuarioService();
      final userData = await perfilService.obtenerDatosUsuario();
      final vendedorId = userData?['usua_IdPersona'] ?? userData?['personaId'];
      
      if (vendedorId == null) {
        throw Exception('No se pudo obtener el ID del vendedor');
      }

      final pedidosService = PedidosService();
      final pedidosRemotos = await pedidosService.getPedidos();
      
      // Obtener pedidos pendientes locales
      final pedidosPendientes = await obtenerPedidosPendientes();
      
      // Filtrar pedidos del vendedor actual
      final vendedorIdInt = vendedorId is int ? vendedorId : int.tryParse(vendedorId.toString()) ?? 0;
      final pedidosFiltrados = pedidosRemotos
          .where((p) => p.vendId == vendedorIdInt)
          .toList();
      
      // Combinar y devolver (primero los pendientes locales)
      return [...pedidosPendientes, ...pedidosFiltrados];
      
    } catch (e) {
      print('Error obteniendo pedidos: $e');
      // En caso de error, devolver los pedidos pendientes locales
      return await obtenerPedidosPendientes();
    }
  }

  /// Guarda los pedidos en caché local
  static Future<void> guardarPedidosEnCache(List<PedidosViewModel> pedidos) async {
    try {
      await guardarJson('pedidos_cache.json', 
          pedidos.map((p) => p.toJson()).toList());
    } catch (e) {
      print('Error guardando pedidos en caché: $e');
      rethrow;
    }
  }

  /// Obtiene los pedidos desde la caché local
  static Future<List<PedidosViewModel>> obtenerPedidosDeCache() async {
    try {
      final data = await leerJson('pedidos_cache.json');
      if (data == null) return [];
      
      return (data as List)
          .map((json) => PedidosViewModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}