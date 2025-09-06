# Productos Offline Service

El `ProductosOffline` es un servicio que permite trabajar con datos de productos, categorías, marcas y subcategorías en modo offline, proporcionando capacidades de cache y sincronización con el servicio remoto.

## Características Principales

- ✅ **Cache inteligente**: Utiliza Flutter Secure Storage para datos JSON pequeños/medianos
- ✅ **Sincronización automática**: Descarga datos desde el servicio remoto y los guarda localmente
- ✅ **Gestión de archivos**: Soporte para guardar/leer archivos binarios (imágenes)
- ✅ **Operaciones atómicas**: Escritura segura de archivos
- ✅ **Fallback a disco**: Respaldo en sistema de archivos cuando sea necesario
- ✅ **Gestión de cache**: Herramientas para limpiar y gestionar el almacenamiento

## Datos Soportados

### Productos
- **Archivo**: `productos.json`
- **Modelo**: `Productos`
- **Servicio**: `ProductosService.getProductos()`

### Categorías
- **Archivo**: `categorias.json`
- **Tipo**: `List<Map<String, dynamic>>`
- **Servicio**: `ProductosService.getCategorias()`

### Marcas
- **Archivo**: `marcas.json`
- **Tipo**: `List<Map<String, dynamic>>`
- **Servicio**: `ProductosService.getMarcas()`

### Subcategorías
- **Archivo**: `subcategorias.json`
- **Tipo**: `List<Map<String, dynamic>>`
- **Servicio**: `ProductosService.getSubcategorias()`

### Productos con Descuento
- **Archivo**: `productos_descuento_{clienteId}_{vendedorId}.json`
- **Modelo**: `ProductoConDescuento`
- **Servicio**: `ProductosService.getProductosConDescuentoPorClienteVendedor()`

## Uso Básico

### Sincronización Completa

```dart
import 'package:sidcop_mobile/Offline_Services/Productos_OfflineService.dart';

// Sincronizar todos los datos de productos
final resultado = await ProductosOffline.sincronizarTodo();
print('Productos: ${(resultado['productos'] as List).length}');
print('Categorías: ${(resultado['categorias'] as List).length}');
print('Marcas: ${(resultado['marcas'] as List).length}');
print('Subcategorías: ${(resultado['subcategorias'] as List).length}');
```

### Trabajar con Productos

```dart
// Obtener productos (preferencia por cache local)
List<Productos> productos = await ProductosOffline.obtenerProductosLocal();

if (productos.isEmpty) {
  // Si no hay cache, sincronizar desde remoto
  productos = await ProductosOffline.sincronizarProductos();
}

// Trabajar con los productos
for (final producto in productos) {
  print('${producto.prod_DescripcionCorta} - \$${producto.prod_PrecioUnitario}');
}
```

### Trabajar con Categorías

```dart
// Leer categorías (usa cache si existe, sino sincroniza)
List<Map<String, dynamic>> categorias = await ProductosOffline.leerCategorias();

// Solo obtener cache local
List<Map<String, dynamic>> categoriasLocal = await ProductosOffline.obtenerCategoriasLocal();

// Forzar sincronización
List<Map<String, dynamic>> categoriasRemoto = await ProductosOffline.sincronizarCategorias();
```

### Productos con Descuento

```dart
// Obtener productos con descuento para cliente/vendedor específico
int clienteId = 123;
int vendedorId = 456;

List<ProductoConDescuento> productosDescuento = 
    await ProductosOffline.sincronizarProductosConDescuento(clienteId, vendedorId);

// Verificar cache local
List<ProductoConDescuento> productosLocal = 
    await ProductosOffline.obtenerProductosConDescuentoLocal(clienteId, vendedorId);
```

## Gestión de Cache

### Verificar Estado del Cache

```dart
// Verificar si existe un archivo específico
bool existeProductos = await ProductosOffline.existe('productos.json');
bool existeCategorias = await ProductosOffline.existe('categorias.json');

// Listar todos los archivos en cache
List<String> archivos = await ProductosOffline.listarArchivos();
for (final archivo in archivos) {
  print('Cache: $archivo');
}

// Obtener tamaño total del cache
int tamanoBytes = await ProductosOffline.obtenerTamanoCache();
print('Cache size: ${tamanoBytes / 1024} KB');
```

### Limpiar Cache

```dart
// Limpiar todo el cache de productos
await ProductosOffline.limpiarCache();

// Borrar archivo específico
await ProductosOffline.borrar('productos.json');
```

## Gestión de Archivos

### Descargar Imágenes de Productos

```dart
// Descargar imagen desde URL
String? rutaLocal = await ProductosOffline.guardarArchivoDesdeUrl(
  'https://ejemplo.com/imagen.jpg',
  'producto_123.jpg',
);

if (rutaLocal != null) {
  print('Imagen guardada en: $rutaLocal');
}
```

### Guardar/Leer Archivos Binarios

```dart
// Guardar bytes
Uint8List imageBytes = ...; // datos de imagen
await ProductosOffline.guardarBytes('imagen.jpg', imageBytes);

// Leer bytes
Uint8List? bytes = await ProductosOffline.leerBytes('imagen.jpg');
if (bytes != null) {
  // Usar los bytes
}
```

## Métodos de Almacenamiento Seguro

Para datos sensibles o configuraciones específicas:

```dart
// Guardar JSON en secure storage con clave personalizada
await ProductosOffline.guardarJsonSeguro('config_productos', {
  'ultima_sincronizacion': DateTime.now().toIso8601String(),
  'version_datos': '1.0'
});

// Leer JSON desde secure storage
dynamic config = await ProductosOffline.leerJsonSeguro('config_productos');
```

## Consideraciones de Rendimiento

### Cache Inteligente
- **Secure Storage**: Para datos JSON pequeños/medianos (< 1MB recomendado)
- **Sistema de archivos**: Fallback automático para archivos grandes
- **Operaciones atómicas**: Previene corrupción de datos

### Estrategias de Sincronización

1. **Sync-First**: Siempre sincronizar desde remoto
```dart
List<Productos> productos = await ProductosOffline.sincronizarProductos();
```

2. **Cache-First**: Usar cache local, sincronizar solo si necesario
```dart
List<Productos> productos = await ProductosOffline.obtenerProductosLocal();
if (productos.isEmpty) {
  productos = await ProductosOffline.sincronizarProductos();
}
```

3. **Hybrid**: Cache para lectura rápida, sync periódico
```dart
List<Map<String, dynamic>> categorias = await ProductosOffline.leerCategorias();
```

## Manejo de Errores

Todos los métodos incluyen manejo de errores y logging:

```dart
try {
  List<Productos> productos = await ProductosOffline.sincronizarProductos();
} catch (e) {
  print('Error sincronizando productos: $e');
  // Fallback a datos locales si existen
  productos = await ProductosOffline.obtenerProductosLocal();
}
```

## Limitaciones Actuales

1. **Productos por Factura**: No se cachean debido a naturaleza específica por factura
2. **Productos con Descuento**: Cache por cliente-vendedor específico
3. **Tamaño de Cache**: Secure Storage recomendado para < 1MB por entrada

## Estructura de Archivos

```
Documents/offline/
├── productos.json           # Lista de productos
├── categorias.json          # Categorías
├── marcas.json             # Marcas
├── subcategorias.json      # Subcategorías
└── productos_descuento_*   # Cache por cliente-vendedor

Secure Storage Keys:
├── json:productos.json
├── json:categorias.json
├── bin:producto_*.jpg      # Imágenes de productos
└── custom_keys...          # Configuraciones personalizadas
```

## Ejemplo Completo

Consulta el archivo `ejemplos/productos_offline_example.dart` para ver ejemplos completos de uso de todas las funcionalidades.
