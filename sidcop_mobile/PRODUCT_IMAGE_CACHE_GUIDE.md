# 📱 Guía del Sistema de Caché de Imágenes de Productos - SIDCOP Mobile

## 🎯 Descripción General

El sistema de caché de imágenes de productos permite que las imágenes se descarguen una vez y se almacenen localmente para visualización offline usando `cached_network_image`. Esto mejora significativamente la experiencia del usuario al navegar por productos sin conexión a internet.

## 🏗️ Arquitectura del Sistema

### Servicios Principales

1. **ProductImageCacheService** - Servicio especializado para caché de imágenes
2. **ProductPreloadService** - Servicio de precarga integrado con caché
3. **CacheService** - Servicio de caché rápido (memoria + SharedPreferences)
4. **EncryptedCsvStorageService** - Almacenamiento cifrado persistente

### Widgets Disponibles

1. **CachedProductImageWidget** - Widget básico de imagen con caché
2. **ProductImageCard** - Card de producto con imagen cacheada
3. **ProductImageListTile** - ListTile con imagen cacheada

## 🚀 Uso Básico

### 1. Widget Simple de Imagen con Caché

```dart
import 'package:sidcop_mobile/widgets/CachedProductImageWidget.dart';

CachedProductImageWidget(
  product: product,
  width: 80,
  height: 80,
  fit: BoxFit.cover,
  borderRadius: BorderRadius.circular(8.0),
  showPlaceholder: true,
)
```

### 2. Card de Producto con Imagen

```dart
ProductImageCard(
  product: product,
  showProductInfo: true,
  onTap: () => _showProductDetails(product),
)
```

### 3. ListTile con Imagen

```dart
ProductImageListTile(
  product: product,
  onTap: () => _selectProduct(product),
  trailing: Icon(Icons.arrow_forward_ios),
)
```

## 🔧 Uso Avanzado

### Cachear Imágenes Manualmente

```dart
import 'package:sidcop_mobile/services/ProductImageCacheService.dart';

final imageCacheService = ProductImageCacheService();

// Cachear todas las imágenes de una lista de productos
final success = await imageCacheService.cacheAllProductImages(products);

if (success) {
  print('Todas las imágenes cacheadas exitosamente');
} else {
  print('Caché completado con algunos errores');
}
```

### Verificar Estado del Caché

```dart
import 'package:sidcop_mobile/services/ProductPreloadService.dart';

final preloadService = ProductPreloadService();

// Verificar si una imagen específica está en caché
final isCached = await preloadService.isImageCached(
  product.prod_Imagen!,
  product.prod_Id.toString(),
);

if (isCached) {
  print('Imagen disponible offline');
} else {
  print('Imagen requiere conexión');
}
```

### Obtener Información del Caché

```dart
final cacheInfo = await imageCacheService.getCacheInfo();

print('Imágenes cacheadas: ${cacheInfo['cachedImages']}/${cacheInfo['totalImages']}');
print('Tamaño del caché: ${cacheInfo['cacheSizeMB']} MB');
```

### Limpiar Caché de Imágenes

```dart
// Limpiar todo el caché de imágenes
await preloadService.clearImageCache();

// O usar el servicio directamente
await imageCacheService.clearImageCache();
```

## ⚙️ Configuración Automática

### Precarga Automática tras Login

El sistema se configura automáticamente para precargar imágenes después del login exitoso:

```dart
// En UsuarioService.dart - esto ya está implementado
Future<Map<String, dynamic>> iniciarSesion(String usuario, String password) async {
  // ... lógica de login ...
  
  if (loginExitoso) {
    // Precarga automática de productos e imágenes
    _preloadService.preloadInBackground();
  }
  
  return result;
}
```

## 🎨 Personalización de Widgets

### CachedProductImageWidget Personalizado

```dart
CachedProductImageWidget(
  product: product,
  width: 120,
  height: 120,
  fit: BoxFit.cover,
  borderRadius: BorderRadius.circular(12),
  showPlaceholder: true,
  // Placeholder personalizado
  placeholder: Container(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.blue),
        SizedBox(height: 8),
        Text('Cargando...', style: TextStyle(fontSize: 10)),
      ],
    ),
  ),
  // Widget de error personalizado
  errorWidget: Container(
    color: Colors.grey[100],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image, color: Colors.grey),
        Text('Error', style: TextStyle(fontSize: 10)),
      ],
    ),
  ),
)
```

## 📊 Monitoreo y Debug

### Logging Detallado

El sistema incluye logging detallado con emojis para facilitar el debug:

```
🖼️ ProductImageCacheService: Iniciando caché de imágenes de productos
📊 ProductImageCacheService: 25 imágenes para cachear
🔄 ProductImageCacheService: Cacheando imagen 1/25 - Producto A
✅ ProductImageCacheService: Imagen 1 cacheada - Producto A
📦 ProductImageCacheService: Lote completado - 5/25 imágenes cacheadas
🎉 ProductImageCacheService: Caché completado - 25/25 imágenes
💾 ProductImageCacheService: Mapeo de imágenes guardado en caché y CSV cifrado
```

### Verificar Estado en Tiempo Real

```dart
// Obtener información completa del caché
final info = await imageCacheService.getCacheInfo();

print('Estado del caché:');
print('- Cacheando: ${info['isCaching']}');
print('- Total imágenes: ${info['totalImages']}');
print('- Imágenes cacheadas: ${info['cachedImages']}');
print('- Tamaño: ${info['cacheSizeMB']} MB');
print('- Mapeos: ${info['mappingCount']}');
```

## 🔒 Seguridad y Persistencia

### Almacenamiento Cifrado

- **Mapeo de imágenes**: Se guarda en CSV cifrado usando AES-256
- **Archivos de imagen**: Se almacenan usando DefaultCacheManager de cached_network_image
- **Caché rápido**: Mapeo en memoria y SharedPreferences para acceso rápido

### Arquitectura de Caché Multi-Nivel

1. **Nivel 1**: Memoria (acceso inmediato)
2. **Nivel 2**: SharedPreferences (caché rápido persistente)
3. **Nivel 3**: CSV cifrado (almacenamiento seguro offline)
4. **Nivel 4**: Archivos locales (imágenes descargadas)

## 🚨 Manejo de Errores

### Timeouts y Reintentos

```dart
// El sistema incluye timeouts automáticos
- Timeout por imagen: 15 segundos
- Procesamiento en lotes: 5 imágenes simultáneas
- Pausa entre lotes: 200ms
```

### Fallbacks Automáticos

```dart
// Si una imagen no se puede cargar:
1. Muestra placeholder durante carga
2. Si falla, muestra widget de error
3. Si no hay conexión, intenta cargar desde caché
4. Si no está en caché, muestra mensaje de error
```

## 📱 Ejemplos Completos

### Ejemplo 1: Pantalla de Productos con Caché

```dart
// Ver: lib/ui/screens/products/products_list_screen.dart
// Ya actualizada para usar CachedProductImageWidget
```

### Ejemplo 2: Demo Interactiva

```dart
// Ver: lib/screens/ProductImageCacheDemo.dart
// Pantalla completa con controles para probar el caché
```

### Ejemplo 3: Ejemplo Educativo

```dart
// Ver: lib/examples/ProductImageCacheExample.dart
// Ejemplo paso a paso con explicaciones
```

## 🔧 Configuración Avanzada

### Personalizar Configuración de Caché

```dart
// En ProductImageCacheService, puedes modificar:
const batchSize = 5; // Número de imágenes simultáneas
Duration(seconds: 15); // Timeout por imagen
Duration(milliseconds: 200); // Pausa entre lotes
```

### Configurar CacheKey Personalizada

```dart
// Las imágenes se cachean con clave única:
cacheKey: 'product_${productId}'
```

## 🎯 Mejores Prácticas

### 1. Uso Eficiente

- ✅ Usa `CachedProductImageWidget` en lugar de `Image.network`
- ✅ Permite que la precarga automática funcione tras el login
- ✅ Verifica el estado del caché antes de operaciones costosas
- ❌ No llames `cacheAllProductImages()` repetidamente

### 2. Manejo de Memoria

- ✅ El sistema limpia automáticamente caché expirado
- ✅ Usa `clearImageCache()` cuando sea necesario liberar espacio
- ✅ Monitorea el tamaño del caché con `getCacheInfo()`

### 3. Experiencia de Usuario

- ✅ Siempre proporciona placeholders durante la carga
- ✅ Maneja estados de error graciosamente
- ✅ Informa al usuario sobre el estado del caché cuando sea relevante

## 🐛 Troubleshooting

### Problema: Imágenes no se cargan offline

**Solución:**
```dart
// Verificar si la imagen está en caché
final isCached = await preloadService.isImageCached(imageUrl, productId);
if (!isCached) {
  // Cachear la imagen manualmente
  await imageCacheService.precacheProductImage(imageUrl, productId);
}
```

### Problema: Caché ocupa mucho espacio

**Solución:**
```dart
// Obtener información del caché
final info = await imageCacheService.getCacheInfo();
print('Tamaño actual: ${info['cacheSizeMB']} MB');

// Limpiar si es necesario
if (info['cacheSizeMB'] > 100) { // Si supera 100MB
  await imageCacheService.clearImageCache();
}
```

### Problema: Imágenes se cargan lentamente

**Solución:**
```dart
// Asegurar que la precarga automática esté funcionando
final preloadInfo = preloadService.getPreloadInfo();
print('Estado de precarga: ${preloadInfo['isPreloaded']}');

// Si no está precargado, forzar precarga
if (!preloadInfo['isPreloaded']) {
  await preloadService.preloadProductsAndImages();
}
```

## 📈 Métricas y Rendimiento

### Métricas Disponibles

- Número total de imágenes
- Imágenes cacheadas exitosamente
- Tamaño total del caché en MB
- Tiempo de precarga
- Tasa de éxito de caché

### Optimizaciones Implementadas

- Procesamiento en lotes para evitar sobrecarga
- Timeouts para evitar bloqueos
- Caché multi-nivel para acceso rápido
- Compresión y cifrado eficientes
- Limpieza automática de caché

---

## 🎉 ¡Listo para Usar!

El sistema de caché de imágenes está completamente implementado y listo para usar. Las imágenes de productos se cachearán automáticamente después del login y estarán disponibles para visualización offline.

Para cualquier duda o problema, revisa los logs del sistema o consulta los ejemplos incluidos en el proyecto.
