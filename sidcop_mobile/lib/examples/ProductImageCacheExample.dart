import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';
import 'package:sidcop_mobile/services/ProductImageCacheService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/widgets/CachedProductImageWidget.dart';

/// Ejemplo completo de uso del sistema de caché de imágenes de productos
class ProductImageCacheExample extends StatefulWidget {
  @override
  _ProductImageCacheExampleState createState() => _ProductImageCacheExampleState();
}

class _ProductImageCacheExampleState extends State<ProductImageCacheExample> {
  final ProductPreloadService _preloadService = ProductPreloadService();
  final ProductImageCacheService _imageCacheService = ProductImageCacheService();
  
  List<Productos> _products = [];
  bool _isLoading = true;
  String _statusMessage = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initializeExample();
  }

  /// Inicializa el ejemplo cargando productos y configurando el caché
  Future<void> _initializeExample() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando productos...';
    });

    try {
      // Paso 1: Obtener productos precargados
      final products = await _preloadService.getPreloadedProducts();
      
      setState(() {
        _products = products;
        _statusMessage = '${products.length} productos cargados. Listo para usar caché de imágenes.';
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Ejemplo de cómo cachear todas las imágenes manualmente
  Future<void> _cacheAllImages() async {
    if (_products.isEmpty) return;

    setState(() {
      _statusMessage = 'Cacheando ${_products.length} imágenes...';
    });

    try {
      final success = await _imageCacheService.cacheAllProductImages(_products);
      
      setState(() {
        _statusMessage = success 
            ? 'Todas las imágenes cacheadas exitosamente ✅'
            : 'Caché completado con algunos errores ⚠️';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error cacheando imágenes: $e';
      });
    }
  }

  /// Ejemplo de cómo verificar si una imagen específica está en caché
  Future<void> _checkImageCache(Productos product) async {
    if (product.prod_Imagen == null) return;

    final isCached = await _preloadService.isImageCached(
      product.prod_Imagen!,
      product.prod_Id.toString(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCached 
              ? '✅ Imagen de "${product.prod_Descripcion}" está en caché'
              : '❌ Imagen de "${product.prod_Descripcion}" NO está en caché',
          style: TextStyle(fontFamily: 'Satoshi'),
        ),
        backgroundColor: isCached ? Colors.green : Colors.orange,
      ),
    );
  }

  /// Ejemplo de cómo limpiar el caché de imágenes
  Future<void> _clearImageCache() async {
    setState(() {
      _statusMessage = 'Limpiando caché de imágenes...';
    });

    try {
      await _preloadService.clearImageCache();
      
      setState(() {
        _statusMessage = 'Caché de imágenes limpiado 🧹';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error limpiando caché: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ejemplo Caché de Imágenes',
          style: TextStyle(
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Panel de control
          _buildControlPanel(),
          
          // Lista de productos
          Expanded(
            child: _isLoading 
                ? _buildLoadingWidget()
                : _buildProductsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Estado actual
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              _statusMessage,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 14,
                color: Colors.blue[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          SizedBox(height: 12),
          
          // Botones de acción
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _cacheAllImages,
                icon: Icon(Icons.download, size: 16),
                label: Text(
                  'Cachear Todas',
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _clearImageCache,
                icon: Icon(Icons.clear_all, size: 16),
                label: Text(
                  'Limpiar Caché',
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _initializeExample,
                icon: Icon(Icons.refresh, size: 16),
                label: Text(
                  'Recargar',
                  style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            _statusMessage,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No hay productos disponibles',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ProductImageListTile(
            product: product,
            onTap: () => _checkImageCache(product),
            trailing: IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: () => _showProductInfo(product),
            ),
          ),
        );
      },
    );
  }

  void _showProductInfo(Productos product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Información del Producto',
          style: TextStyle(fontFamily: 'Satoshi'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto usando el widget con caché
            Container(
              height: 150,
              width: double.infinity,
              child: CachedProductImageWidget(
                product: product,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            
            SizedBox(height: 16),
            
            Text(
              'ID: ${product.prod_Id}',
              style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
            ),
            Text(
              'Descripción: ${product.prod_Descripcion ?? "N/A"}',
              style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
            ),
            Text(
              'Precio: L. ${product.prod_PrecioUnitario.toStringAsFixed(2)}',
              style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
            ),
            Text(
              'Marca: ${product.marc_Descripcion ?? "N/A"}',
              style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
            ),
            Text(
              'Categoría: ${product.cate_Descripcion ?? "N/A"}',
              style: TextStyle(fontFamily: 'Satoshi', fontSize: 12),
            ),
            
            SizedBox(height: 12),
            
            // Estado del caché para esta imagen
            FutureBuilder<bool>(
              future: product.prod_Imagen != null 
                  ? _preloadService.isImageCached(
                      product.prod_Imagen!,
                      product.prod_Id.toString(),
                    )
                  : Future.value(false),
              builder: (context, snapshot) {
                final isCached = snapshot.data ?? false;
                return Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCached ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCached ? Colors.green[200]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCached ? Icons.check_circle : Icons.cloud_download,
                        color: isCached ? Colors.green[600] : Colors.orange[600],
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isCached ? 'Imagen en caché' : 'Imagen no cacheada',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                          color: isCached ? Colors.green[600] : Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cerrar',
              style: TextStyle(fontFamily: 'Satoshi'),
            ),
          ),
        ],
      ),
    );
  }
}
