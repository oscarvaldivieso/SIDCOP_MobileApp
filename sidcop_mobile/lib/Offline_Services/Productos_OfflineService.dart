import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';

/// Servicios para operaciones offline: guardar/leer JSON y archivos binarios.

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//PRODUCTOS SCREEN Y PRODUCTOS DETAILS
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class ProductosOffline {
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

  /// Guarda cualquier objeto JSON-serializable en `nombreArchivo` (por ejemplo: 'productos.json').
  /// La escritura es atómica: escribe en un temporal y renombra.
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      final key = 'json:$nombreArchivo';
      final contenido = jsonEncode(objeto);
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      //print('Error guardando JSON $nombreArchivo: $e');
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
      //print('Error leyendo JSON $nombreArchivo: $e');
      return null;
    }
  }

  /// Guarda bytes en un archivo (por ejemplo imágenes, mbtiles). Escritura atómica.
  static Future<void> guardarBytes(
    String nombreArchivo,
    Uint8List bytes,
  ) async {
    try {
      final key = 'bin:$nombreArchivo';
      final encoded = base64Encode(bytes);
      await _secureStorage.write(key: key, value: encoded);
    } catch (e) {
      //print('Error guardando bytes $nombreArchivo: $e');
      rethrow;
    }
  }

  /// Lee bytes desde un archivo. Devuelve null si no existe.
  static Future<Uint8List?> leerBytes(String nombreArchivo) async {
    try {
      final key = 'bin:$nombreArchivo';
      final encoded = await _secureStorage.read(key: key);
      if (encoded != null) {
        return base64Decode(encoded);
      }
      
      // Fallback: intentar leer desde disco
      final ruta = await _rutaArchivo(nombreArchivo);
      final archivo = File(ruta);
      if (await archivo.exists()) {
        return await archivo.readAsBytes();
      }
      
      return null;
    } catch (e) {
      //print('Error leyendo bytes $nombreArchivo: $e');
      return null;
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
      //print('Error borrando archivo $nombreArchivo: $e');
    }
  }

  /// Lista los nombres de archivos dentro de la carpeta offline (no recursivo).
  static Future<List<String>> listarArchivos() async {
    // Listar archivos en carpeta offline + JSON almacenados en secure storage
    final archivos = <String>[];
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
    // Añadir keys guardadas en secure storage (prefijo 'json:' y 'bin:')
    try {
      final allKeys = await _secureStorage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith('json:')) {
          final filename = key.substring(5);
          if (!archivos.contains(filename)) archivos.add(filename);
        } else if (key.startsWith('bin:')) {
          final filename = key.substring(4);
          if (!archivos.contains(filename)) archivos.add(filename);
        }
      }
    } catch (_) {
      // Ignorar errores de secure storage
    }
    return archivos;
  }

  // Funciones de conveniencia para productos (json en 'productos.json')
  static const String _archivoProductos = 'productos.json';

  static Future<void> guardarProductos(
    List<Productos> productos,
  ) async {
    await guardarJson(_archivoProductos, productos.map((p) => p.toJson()).toList());
  }

  static Future<List<Productos>> cargarProductos() async {
    final raw = await leerJson(_archivoProductos);
    if (raw == null) return [];
    try {
      final List<dynamic> lista = List.from(raw as List);
      return lista.map((json) => Productos.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      //print('Error parseando productos: $e');
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
      //print('Error guardando JSON seguro $key: $e');
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
      //print('Error leyendo JSON seguro $key: $e');
      return null;
    }
  }

  // -----------------------------
  // Helpers específicos para 'details' de productos
  // -----------------------------
  /// Guarda los detalles de un producto en secure storage bajo la clave 'details_producto_<id>'
  static Future<void> guardarDetallesProducto(
    int productoId,
    Map<String, dynamic> detalles,
  ) async {
    final key = 'details_producto_$productoId';
    await guardarJsonSeguro(key, detalles);
  }

  /// Lee los detalles de un producto desde secure storage; devuelve null si no existe
  static Future<Map<String, dynamic>?> leerDetallesProducto(int productoId) async {
    final key = 'details_producto_$productoId';
    final raw = await leerJsonSeguro(key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  /// Borra los detalles de un producto de secure storage (si existen)
  static Future<void> borrarDetallesProducto(int productoId) async {
    final key = 'details_producto_$productoId';
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      //print('Error borrando detalles producto $productoId: $e');
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
  static Future<String?> guardarImagenDeProductoStatic(
    String imageUrl,
    String nombreArchivo,
  ) async {
    // Per requirement: offline service must not download or call remote static
    // map endpoints. Image caching must be handled by the UI while online.
    // Keep a placeholder implementation for legacy callers.
    return null;
  }

  // -----------------------------
  // Métodos de sincronización con los endpoints usados en pantalla 'Productos'
  // Estos métodos consultan los servicios remotos y almacenan la copia
  // local utilizando las funciones anteriores (guardarJson).
  // -----------------------------

  /// Sincroniza los productos desde el endpoint y los guarda en 'productos.json'.
  static Future<List<Productos>> sincronizarProductos() async {
    try {
      final service = ProductosService();
      final data = await service.getProductos();
      await guardarProductos(data);
      return data;
    } catch (e) {
      //print('Error sincronizando productos: $e');
      return [];
    }
  }

  /// Sincroniza las categorías desde el endpoint y las guarda en 'categorias.json'.
  static Future<List<Map<String, dynamic>>> sincronizarCategorias() async {
    try {
      final service = ProductosService();
      final data = await service.getCategorias();
      await guardarJson('categorias.json', data);
      return data;
    } catch (e) {
      //print('Error sincronizando categorías: $e');
      return [];
    }
  }

  /// Sincroniza las subcategorías desde el endpoint y las guarda en 'subcategorias.json'.
  static Future<List<Map<String, dynamic>>> sincronizarSubcategorias() async {
    try {
      final service = ProductosService();
      final data = await service.getSubcategorias();
      await guardarJson('subcategorias.json', data);
      return data;
    } catch (e) {
      //print('Error sincronizando subcategorías: $e');
      return [];
    }
  }

  /// Sincroniza las marcas desde el endpoint y las guarda en 'marcas.json'.
  static Future<List<Map<String, dynamic>>> sincronizarMarcas() async {
    try {
      final service = ProductosService();
      final data = await service.getMarcas();
      await guardarJson('marcas.json', data);
      return data;
    } catch (e) {
      //print('Error sincronizando marcas: $e');
      return [];
    }
  }

  /// Guarda la imagen de un producto (nombre: 'imagen_producto_<productoId>.jpg').
  static Future<void> guardarImagenProducto(
    String productoId,
    Uint8List bytes,
  ) async {
    final filename = 'imagen_producto_${productoId}.jpg';
    await guardarBytes(filename, bytes);
  }

  /// Lee la imagen de un producto si existe.
  static Future<Uint8List?> leerImagenProducto(String productoId) async {
    final filename = 'imagen_producto_${productoId}.jpg';
    return await leerBytes(filename);
  }

  /// Devuelve la ruta absoluta en disco del archivo de imagen del producto si
  /// existe, o null si no está disponible en disco. Esto es útil para
  /// widgets que prefieren `Image.file(File(path))`.
  static Future<String?> rutaImagenProductoLocal(String productoId) async {
    final filename = 'imagen_producto_${productoId}.jpg';
    try {
      final ruta = await _rutaArchivo(filename);
      final archivo = File(ruta);
      if (await archivo.exists()) {
        return ruta;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sincroniza Productos, Categorías, Subcategorías y Marcas en paralelo y devuelve
  /// un mapa con los resultados. Si alguna falla, la excepción se propaga.
  static Future<Map<String, dynamic>> sincronizarProductos_Todo() async {
    try {
      final resultados = await Future.wait([
        sincronizarProductos(),
        sincronizarCategorias(),
        sincronizarSubcategorias(),
        sincronizarMarcas(),
      ]);

      return {
        'productos': resultados[0],
        'categorias': resultados[1],
        'subcategorias': resultados[2],
        'marcas': resultados[3],
      };
    } catch (e) {
      //print('Error en sincronización completa de productos: $e');
      rethrow;
    }
  }

  /// Genera y guarda los detalles para todos los productos disponibles.
  /// Usa datos locales si existen, o sincroniza los productos remotos si no hay datos locales.
  static Future<void> guardarDetallesTodosProductos({bool forzar = false}) async {
    try {
      List<Productos> productos;
      
      if (forzar) {
        productos = await sincronizarProductos();
      } else {
        productos = await obtenerProductosLocal();
        if (productos.isEmpty) {
          productos = await sincronizarProductos();
        }
      }

      // Generar detalles para cada producto
      for (final producto in productos) {
        final detalles = {
          'id': producto.prod_Id,
          'descripcion': producto.prod_Descripcion,
          'codigo': producto.prod_Codigo,
          'precio': producto.prod_PrecioUnitario,
          'marca': producto.marc_Descripcion,
          'categoria': producto.cate_Descripcion,
          'proveedor': producto.prov_NombreEmpresa,
          'descripcionCorta': producto.prod_DescripcionCorta,
          'fechaActualizacion': DateTime.now().toIso8601String(),
        };
        
        await guardarDetallesProducto(producto.prod_Id, detalles);
      }
      
      //print('Detalles guardados para ${productos.length} productos');
    } catch (e) {
      //print('Error guardando detalles de productos: $e');
      rethrow;
    }
  }

  // -----------------------------
  // Métodos de lectura con los archivos de Productos
  // -----------------------------
  /// Devuelve los productos almacenados localmente (productos.json) o lista vacía.
  static Future<List<Productos>> obtenerProductosLocal() async {
    final raw = await leerJson('productos.json');
    if (raw == null) return [];
    try {
      final List<dynamic> lista = List.from(raw as List);
      return lista.map((json) => Productos.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      //print('Error parseando productos locales: $e');
      return [];
    }
  }

  /// Fuerza sincronización remota y devuelve los datos.
  static Future<List<Productos>> leerProductos() async {
    return await sincronizarProductos();
  }

  /// Categorías locales (categorias.json) - VERSIÓN CORREGIDA
  static Future<List<Map<String, dynamic>>> obtenerCategoriasLocal() async {
    final raw = await leerJson('categorias.json');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      //print('Error parseando categorías locales: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> leerCategorias() async {
    // Primero intentar obtener datos locales
    final local = await obtenerCategoriasLocal();
    if (local.isNotEmpty) {
      return local;
    }
    // Solo sincronizar si no hay datos locales
    return await sincronizarCategorias();
  }

  /// Subcategorías locales - VERSIÓN CORREGIDA
  static Future<List<Map<String, dynamic>>> obtenerSubcategoriasLocal() async {
    final raw = await leerJson('subcategorias.json');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      //print('Error parseando subcategorías locales: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> leerSubcategorias() async {
    // Primero intentar obtener datos locales
    final local = await obtenerSubcategoriasLocal();
    if (local.isNotEmpty) {
      return local;
    }
    // Solo sincronizar si no hay datos locales
    return await sincronizarSubcategorias();
  }

  /// Marcas locales - VERSIÓN CORREGIDA
  static Future<List<Map<String, dynamic>>> obtenerMarcasLocal() async {
    final raw = await leerJson('marcas.json');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      //print('Error parseando marcas locales: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> leerMarcas() async {
    // Primero intentar obtener datos locales
    final local = await obtenerMarcasLocal();
    if (local.isNotEmpty) {
      return local;
    }
    // Solo sincronizar si no hay datos locales
    return await sincronizarMarcas();
  }

  /// Sincroniza productos con descuento para un cliente y vendedor específicos.
  static Future<List<ProductoConDescuento>> sincronizarProductosConDescuento(
    int clienteId, 
    int vendedorId
  ) async {
    try {
      final service = ProductosService();
      final data = await service.getProductosConDescuentoPorClienteVendedor(clienteId, vendedorId);
      
      // Cachear por cliente-vendedor específico
      final cacheKey = 'productos_descuento_${clienteId}_$vendedorId.json';
      await guardarJson(cacheKey, data.map((p) => p.toJson()).toList());
      
      return data;
    } catch (e) {
      //print('Error sincronizando productos con descuento: $e');
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
      //print('Error parseando productos con descuento locales: $e');
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
      //print('Error obteniendo productos por factura: $e');
      return [];
    }
  }

  /// Limpia todo el cache de productos (útil para forzar resincronización).
  static Future<void> limpiarCache() async {
    await Future.wait([
      borrar('productos.json'),
      borrar('categorias.json'),
      borrar('subcategorias.json'),
      borrar('marcas.json'),
    ]);
  }

  /// Consolidación de sincronización de productos
  static Future<void> sincronizarTodo() async {
    try {
      await sincronizarProductos_Todo();
      //print('Sincronización completa de productos finalizada');
    } catch (e) {
      //print('Error en sincronización completa: $e');
      rethrow;
    }
  }
}
