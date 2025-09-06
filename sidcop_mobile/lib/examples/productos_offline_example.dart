import 'package:sidcop_mobile/Offline_Services/Productos_OfflineService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';

/// Ejemplo de uso del servicio offline de Productos
class EjemploProductosOffline {
  
  /// Ejemplo: Sincronizar todos los datos de productos
  static Future<void> ejemploSincronizarTodo() async {
    try {
      print('Iniciando sincronización completa de productos...');
      
      final resultado = await ProductosOffline.sincronizarTodo();
      
      print('Sincronización completada:');
      print('- Productos: ${(resultado['productos'] as List).length}');
      print('- Categorías: ${(resultado['categorias'] as List).length}');
      print('- Marcas: ${(resultado['marcas'] as List).length}');
      print('- Subcategorías: ${(resultado['subcategorias'] as List).length}');
      
    } catch (e) {
      print('Error en sincronización: $e');
    }
  }

  /// Ejemplo: Trabajar con productos en modo offline
  static Future<void> ejemploTrabajarOffline() async {
    try {
      // 1. Intentar leer productos locales primero
      List<Productos> productos = await ProductosOffline.obtenerProductosLocal();
      
      if (productos.isEmpty) {
        print('No hay productos locales, sincronizando...');
        productos = await ProductosOffline.sincronizarProductos();
      } else {
        print('Usando productos locales: ${productos.length} elementos');
      }

      // 2. Trabajar con categorías offline
      List<Map<String, dynamic>> categorias = await ProductosOffline.leerCategorias();
      print('Categorías disponibles: ${categorias.length}');

      // 3. Obtener marcas
      List<Map<String, dynamic>> marcas = await ProductosOffline.leerMarcas();
      print('Marcas disponibles: ${marcas.length}');

      // 4. Mostrar algunos productos
      if (productos.isNotEmpty) {
        print('\nPrimeros 3 productos:');
        for (int i = 0; i < 3 && i < productos.length; i++) {
          final producto = productos[i];
          print('${i + 1}. ${producto.prod_DescripcionCorta ?? "Sin descripción"} - \$${producto.prod_PrecioUnitario}');
        }
      }

    } catch (e) {
      print('Error trabajando offline: $e');
    }
  }

  /// Ejemplo: Trabajar con productos con descuento
  static Future<void> ejemploProductosConDescuento(int clienteId, int vendedorId) async {
    try {
      print('Obteniendo productos con descuento para cliente $clienteId, vendedor $vendedorId...');
      
      // Intentar obtener desde cache local primero
      List<ProductoConDescuento> productosLocal = 
          await ProductosOffline.obtenerProductosConDescuentoLocal(clienteId, vendedorId);
      
      if (productosLocal.isNotEmpty) {
        print('Usando productos con descuento desde cache: ${productosLocal.length} elementos');
      } else {
        print('Cache vacío, sincronizando productos con descuento...');
        productosLocal = await ProductosOffline.sincronizarProductosConDescuento(clienteId, vendedorId);
      }

      // Mostrar algunos productos con descuento
      if (productosLocal.isNotEmpty) {
        print('\nProductos con descuento:');
        for (int i = 0; i < 3 && i < productosLocal.length; i++) {
          final producto = productosLocal[i];
          print('${i + 1}. ${producto.prodDescripcionCorta}');
          print('   Precio unitario: \$${producto.prodPrecioUnitario}');
          print('   Disponible: ${producto.cantidadDisponible}');
          print('   Listas de precio: ${producto.listasPrecio.length}');
          print('   Descuentos por escala: ${producto.descuentosEscala.length}');
        }
      }

    } catch (e) {
      print('Error con productos con descuento: $e');
    }
  }

  /// Ejemplo: Gestión de cache
  static Future<void> ejemploGestionCache() async {
    try {
      // Verificar tamaño del cache
      final tamanoCache = await ProductosOffline.obtenerTamanoCache();
      print('Tamaño actual del cache: ${tamanoCache} bytes');

      // Listar archivos offline
      final archivos = await ProductosOffline.listarArchivos();
      print('Archivos en cache: ${archivos.length}');
      for (final archivo in archivos) {
        print('- $archivo');
      }

      // Verificar existencia de archivos específicos
      final existeProductos = await ProductosOffline.existe('productos.json');
      final existeCategorias = await ProductosOffline.existe('categorias.json');
      
      print('\nEstado del cache:');
      print('- Productos: ${existeProductos ? "✓" : "✗"}');
      print('- Categorías: ${existeCategorias ? "✓" : "✗"}');

      // Opcionalmente limpiar cache si es muy grande
      if (tamanoCache > 1024 * 1024) { // 1MB
        print('\nCache muy grande, limpiando...');
        await ProductosOffline.limpiarCache();
        print('Cache limpiado');
      }

    } catch (e) {
      print('Error gestionando cache: $e');
    }
  }

  /// Ejemplo: Descarga de archivos (imágenes de productos)
  static Future<void> ejemploDescargarImagenes() async {
    try {
      // Obtener productos locales
      final productos = await ProductosOffline.obtenerProductosLocal();
      
      print('Descargando imágenes de productos...');
      int descargadas = 0;
      
      for (final producto in productos.take(5)) { // Solo los primeros 5
        if (producto.prod_Imagen != null && producto.prod_Imagen!.isNotEmpty) {
          final nombreArchivo = 'producto_${producto.prod_Id}.jpg';
          final rutaArchivo = await ProductosOffline.guardarArchivoDesdeUrl(
            producto.prod_Imagen!,
            nombreArchivo,
          );
          
          if (rutaArchivo != null) {
            print('Imagen descargada: $nombreArchivo -> $rutaArchivo');
            descargadas++;
          }
        }
      }
      
      print('Total de imágenes descargadas: $descargadas');
      
    } catch (e) {
      print('Error descargando imágenes: $e');
    }
  }

  /// Método principal para ejecutar todos los ejemplos
  static Future<void> ejecutarEjemplos() async {
    print('=== EJEMPLOS DE USO - PRODUCTOS OFFLINE SERVICE ===\n');
    
    await ejemploSincronizarTodo();
    print('\n' + '='*50 + '\n');
    
    await ejemploTrabajarOffline();
    print('\n' + '='*50 + '\n');
    
    // Ejemplo con IDs ficticios - cambiar por IDs reales
    await ejemploProductosConDescuento(1, 1);
    print('\n' + '='*50 + '\n');
    
    await ejemploGestionCache();
    print('\n' + '='*50 + '\n');
    
    await ejemploDescargarImagenes();
    print('\n=== FIN DE EJEMPLOS ===');
  }
}
