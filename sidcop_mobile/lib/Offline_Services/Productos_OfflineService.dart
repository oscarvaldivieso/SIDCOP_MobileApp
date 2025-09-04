import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';

/// Servicio offline para operaciones relacionadas con productos.
class ProductosOffline {
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
      final key = 'json:$nombreArchivo';
      final contenido = jsonEncode(objeto);
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      print('Error guardando JSON $nombreArchivo: $e');
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde `nombreArchivo`. Devuelve null si no existe.
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = 'json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s == null || s.isEmpty) return null;
      return jsonDecode(s);
    } catch (e) {
      print('Error leyendo JSON $nombreArchivo: $e');
      return null;
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
      print('Error guardando bytes $nombreArchivo: $e');
      rethrow;
    }
  }

  /// Lee bytes desde secure storage (preferido) o desde disco si existe.
  /// Devuelve null si no existe.
  static Future<Uint8List?> leerBytes(String nombreArchivo) async {
    try {
      final key = 'bin:$nombreArchivo';
      final encoded = await _secureStorage.read(key: key);
      if (encoded != null) {
        final bytes = base64Decode(encoded);
        return Uint8List.fromList(bytes);
      }
      
      // Fallback: intentar leer desde disco
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) {
        final bytes = await archivo.readAsBytes();
        return Uint8List.fromList(bytes);
      }
      
      return null;
    } catch (e) {
      print('Error leyendo bytes $nombreArchivo: $e');
      return null;
    }
  }

  /// Comprueba si un archivo existe en secure storage o en disco.
  static Future<bool> existe(String nombreArchivo) async {
    if (nombreArchivo.toLowerCase().endsWith('.json')) {
      final key = 'json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s != null) return true;
    } else {
      final binKey = 'bin:$nombreArchivo';
      final b = await _secureStorage.read(key: binKey);
      if (b != null) return true;
    }

    final ruta = await _rutaArchivo(nombreArchivo);
    final archivo = File(ruta);
    return archivo.exists();
  }

  /// Borra un archivo (json o bin) si existe.
  static Future<void> borrar(String nombreArchivo) async {
    try {
      // Borrar de secure storage
      if (nombreArchivo.toLowerCase().endsWith('.json')) {
        final key = 'json:$nombreArchivo';
        await _secureStorage.delete(key: key);
      } else {
        final binKey = 'bin:$nombreArchivo';
        await _secureStorage.delete(key: binKey);
      }
      
      // Borrar de disco (fallback)
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (e) {
      print('Error borrando archivo $nombreArchivo: $e');
    }
  }

  /// Lista los nombres de archivos dentro de la carpeta offline (no recursivo)
  /// y añade keys guardadas en secure storage.
  static Future<List<String>> listarArchivos() async {
    final archivos = <String>[];
    
    // Archivos en disco
    final docs = await _directorioDocuments();
    final carpeta = Directory(p.join(docs.path, _carpetaOffline));
    if (await carpeta.exists()) {
      final entities = await carpeta.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          archivos.add(p.basename(entity.path));
        }
      }
    }
    
    // Archivos en secure storage
    try {
      final allKeys = await _secureStorage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('json:') || key.startsWith('bin:')) {
          final fileName = key.substring(4); // Remove 'json:' or 'bin:'
          if (!archivos.contains(fileName)) {
            archivos.add(fileName);
          }
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
      print('Error guardando JSON seguro $key: $e');
      rethrow;
    }
  }

  /// Lee y decodifica un JSON almacenado en secure storage bajo `key`. Devuelve null si no existe.
  static Future<dynamic> leerJsonSeguro(String key) async {
    try {
      final s = await _secureStorage.read(key: key);
      if (s == null || s.isEmpty) return null;
      return jsonDecode(s);
    } catch (e) {
      print('Error leyendo JSON seguro $key: $e');
      return null;
    }
  }

  // -----------------------------
  // Helpers específicos para Productos
  // -----------------------------
  static const String _archivoProductos = 'productos.json';
  static const String _archivoCategorias = 'categorias.json';
  static const String _archivoMarcas = 'marcas.json';
  static const String _archivoSubcategorias = 'subcategorias.json';

  /// Sincroniza la lista de productos desde el servicio remoto y guarda localmente.
  static Future<List<Productos>> sincronizarProductos() async {
    try {
      final service = ProductosService();
      final data = await service.getProductos();
      await guardarJson(_archivoProductos, data.map((p) => p.toJson()).toList());
      return data;
    } catch (e) {
      print('Error sincronizando productos: $e');
      return [];
    }
  }

  /// Guarda manualmente una lista de productos en el almacenamiento local.
  static Future<void> guardarProductos(List<Productos> productos) async {
    await guardarJson(_archivoProductos, productos.map((p) => p.toJson()).toList());
  }

  /// Lee la lista de productos almacenada localmente o devuelve lista vacía.
  static Future<List<Productos>> obtenerProductosLocal() async {
    final raw = await leerJson(_archivoProductos);
    if (raw == null) return [];
    
    try {
      final List<dynamic> list = List.from(raw as List);
      return list.map((json) => Productos.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error parseando productos locales: $e');
      return [];
    }
  }

  /// Wrapper que fuerza lectura/sincronización remota para productos (si se necesita).
  static Future<List<Productos>> leerProductos() async {
    return await sincronizarProductos();
  }

  /// Sincroniza las categorías desde el servicio remoto y guarda localmente.
  static Future<List<Map<String, dynamic>>> sincronizarCategorias() async {
    try {
      final service = ProductosService();
      final data = await service.getCategorias();
      await guardarJson(_archivoCategorias, data);
      return data;
    } catch (e) {
      print('Error sincronizando categorías: $e');
      return [];
    }
  }

  /// Guarda manualmente una lista de categorías en el almacenamiento local.
  static Future<void> guardarCategorias(List<Map<String, dynamic>> categorias) async {
    await guardarJson(_archivoCategorias, categorias);
  }

  /// Lee categorías locales o devuelve lista vacía.
  static Future<List<Map<String, dynamic>>> obtenerCategoriasLocal() async {
    final raw = await leerJson(_archivoCategorias);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  /// Lee las categorías preferiendo el cache local. Si no hay datos
  /// locales, intenta sincronizar desde el servicio remoto y los guarda.
  static Future<List<Map<String, dynamic>>> leerCategorias() async {
    final local = await obtenerCategoriasLocal();
    if (local.isNotEmpty) return local;
    return await sincronizarCategorias();
  }

  /// Sincroniza las marcas desde el servicio remoto y guarda localmente.
  static Future<List<Map<String, dynamic>>> sincronizarMarcas() async {
    try {
      final service = ProductosService();
      final data = await service.getMarcas();
      await guardarJson(_archivoMarcas, data);
      return data;
    } catch (e) {
      print('Error sincronizando marcas: $e');
      return [];
    }
  }

  /// Guarda manualmente una lista de marcas en el almacenamiento local.
  static Future<void> guardarMarcas(List<Map<String, dynamic>> marcas) async {
    await guardarJson(_archivoMarcas, marcas);
  }

  /// Lee marcas locales o devuelve lista vacía.
  static Future<List<Map<String, dynamic>>> obtenerMarcasLocal() async {
    final raw = await leerJson(_archivoMarcas);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  /// Lee las marcas preferiendo el cache local. Si no hay datos
  /// locales, intenta sincronizar desde el servicio remoto y los guarda.
  static Future<List<Map<String, dynamic>>> leerMarcas() async {
    final local = await obtenerMarcasLocal();
    if (local.isNotEmpty) return local;
    return await sincronizarMarcas();
  }

  /// Sincroniza las subcategorías desde el servicio remoto y guarda localmente.
  static Future<List<Map<String, dynamic>>> sincronizarSubcategorias() async {
    try {
      final service = ProductosService();
      final data = await service.getSubcategorias();
      await guardarJson(_archivoSubcategorias, data);
      return data;
    } catch (e) {
      print('Error sincronizando subcategorías: $e');
      return [];
    }
  }

  /// Guarda manualmente una lista de subcategorías en el almacenamiento local.
  static Future<void> guardarSubcategorias(List<Map<String, dynamic>> subcategorias) async {
    await guardarJson(_archivoSubcategorias, subcategorias);
  }

  /// Lee subcategorías locales o devuelve lista vacía.
  static Future<List<Map<String, dynamic>>> obtenerSubcategoriasLocal() async {
    final raw = await leerJson(_archivoSubcategorias);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  /// Lee las subcategorías preferiendo el cache local. Si no hay datos
  /// locales, intenta sincronizar desde el servicio remoto y los guarda.
  static Future<List<Map<String, dynamic>>> leerSubcategorias() async {
    final local = await obtenerSubcategoriasLocal();
    if (local.isNotEmpty) return local;
    return await sincronizarSubcategorias();
  }

  /// Sincroniza productos con descuento para un cliente y vendedor específicos.
  /// Nota: Esta función requiere parámetros específicos, por lo que no se puede 
  /// cachear de manera genérica. Se recomienda usar directamente el servicio.
  static Future<List<ProductoConDescuento>> sincronizarProductosConDescuento(
    int clienteId, 
    int vendedorId
  ) async {
    try {
      final service = ProductosService();
      final data = await service.getProductosConDescuentoPorClienteVendedor(clienteId, vendedorId);
      
      // Opcionalmente cachear por cliente-vendedor específico
      final cacheKey = 'productos_descuento_${clienteId}_$vendedorId.json';
      await guardarJson(cacheKey, data.map((p) => p.toJson()).toList());
      
      return data;
    } catch (e) {
      print('Error sincronizando productos con descuento: $e');
      return [];
    }
  }

  /// Lee productos con descuento cacheados para un cliente y vendedor específicos.
  static Future<List<ProductoConDescuento>> obtenerProductosConDescuentoLocal(
    int clienteId, 
    int vendedorId
  ) async {
    final cacheKey = 'productos_descuento_${clienteId}_$vendedorId.json';
    final raw = await leerJson(cacheKey);
    if (raw == null) return [];
    
    try {
      final List<dynamic> list = List.from(raw as List);
      return list.map((json) => ProductoConDescuento.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error parseando productos con descuento locales: $e');
      return [];
    }
  }

  /// Obtiene productos por factura. Nota: Esta función requiere un facturaId específico,
  /// por lo que se recomienda usar directamente el servicio para datos en tiempo real.
  static Future<List<Map<String, dynamic>>> obtenerProductosPorFactura(int facturaId) async {
    try {
      final service = ProductosService();
      return await service.getProductosPorFactura(facturaId);
    } catch (e) {
      print('Error obteniendo productos por factura: $e');
      return [];
    }
  }

  /// Sincroniza todos los datos de productos (productos, categorías, marcas, subcategorías)
  /// en paralelo y devuelve un mapa con los resultados.
  static Future<Map<String, dynamic>> sincronizarTodo() async {
    try {
      final futures = await Future.wait([
        sincronizarProductos(),
        sincronizarCategorias(),
        sincronizarMarcas(),
        sincronizarSubcategorias(),
      ]);

      return {
        'productos': futures[0],
        'categorias': futures[1],
        'marcas': futures[2],
        'subcategorias': futures[3],
      };
    } catch (e) {
      print('Error en sincronización completa de productos: $e');
      rethrow;
    }
  }

  /// Devuelve la ruta absoluta en Documents para un nombre de archivo simple.
  static Future<String> rutaEnDocuments(String nombreArchivo) async {
    final docs = await _directorioDocuments();
    return p.join(docs.path, nombreArchivo);
  }

  /// Descarga y guarda un archivo (por ejemplo imagen de producto) en Documents.
  static Future<String?> guardarArchivoDesdeUrl(
    String url,
    String nombreArchivo,
  ) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final ruta = await rutaEnDocuments(nombreArchivo);
        final archivo = File(ruta);
        await archivo.writeAsBytes(response.bodyBytes);
        return ruta;
      }
    } catch (e) {
      print('Error descargando archivo desde URL $url: $e');
    }
    return null;
  }

  /// Limpia todo el cache de productos (útil para forzar resincronización).
  static Future<void> limpiarCache() async {
    await Future.wait([
      borrar(_archivoProductos),
      borrar(_archivoCategorias),
      borrar(_archivoMarcas),
      borrar(_archivoSubcategorias),
    ]);
  }

  /// Obtiene el tamaño total aproximado del cache de productos en secure storage.
  static Future<int> obtenerTamanoCache() async {
    int totalSize = 0;
    
    try {
      final allKeys = await _secureStorage.readAll();
      for (final entry in allKeys.entries) {
        if (entry.key.startsWith('json:productos') || 
            entry.key.startsWith('json:categorias') ||
            entry.key.startsWith('json:marcas') ||
            entry.key.startsWith('json:subcategorias') ||
            entry.key.startsWith('bin:producto_')) {
          totalSize += entry.value.length;
        }
      }
    } catch (e) {
      print('Error calculando tamaño del cache: $e');
    }
    
    return totalSize;
  }
}
