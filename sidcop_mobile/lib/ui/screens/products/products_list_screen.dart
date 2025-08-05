import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductosService _productosService = ProductosService();
  final TextEditingController _searchController = TextEditingController();

  List<Productos> _allProducts = [];
  List<Productos> _filteredProducts = [];
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _subcategorias = [];
  List<Map<String, dynamic>> _marcas = [];
  bool _filtersLoaded = false;

  // Filtros
  final Map<String, Set<int>> _selectedFilters = {
    'categorias': {},
    'subcategorias': {},
    'marcas': {},
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadFilters(); // Cargar filtros
    _searchController.addListener(_applyFilters);
  }

  /// Método optimizado para cargar productos usando precarga cuando esté disponible
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      // PASO 1: Verificar si los productos están precargados
      if (ProductPreloadService.isPreloaded()) {
        debugPrint('⚡ Usando productos precargados (carga instantánea)');
        
        // Obtener productos precargados directamente
        _allProducts = ProductPreloadService.getPreloadedProducts();
        _filteredProducts = List.from(_allProducts);
        
        debugPrint('✅ Productos cargados instantáneamente: ${_allProducts.length}');
        
        // Actualizar UI inmediatamente
        setState(() => _isLoading = false);
        return;
      }
      
      // PASO 2: Si no están precargados, cargar normalmente
      debugPrint('🔄 Productos no precargados, cargando desde servidor/caché...');
      
      // Usar SyncService.getProducts() para aprovechar funcionalidad offline
      final productsData = await SyncService.getProducts();
      
      // Convertir List<Map<String, dynamic>> a List<Productos>
      _allProducts = productsData.map((productMap) => 
        Productos.fromJson(productMap)
      ).toList();
      
      _filteredProducts = List.from(_allProducts);
      debugPrint('✅ Productos cargados desde servidor/caché: ${_allProducts.length}');
      
      // PASO 3: Iniciar precarga en segundo plano para próximas veces
      if (!ProductPreloadService.isPreloading()) {
        debugPrint('🚀 Iniciando precarga en segundo plano para futuras cargas...');
        ProductPreloadService.preloadInBackground();
      }
      
    } catch (e) {
      debugPrint('❌ Error cargando productos: $e');
      
      // Mostrar mensaje de error al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cargando productos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final searchTerm = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Filtro por búsqueda
        final matchesSearch =
            searchTerm.isEmpty ||
            (product.prod_Descripcion?.toLowerCase().contains(searchTerm) ??
                false ||
                    (product.prod_Codigo?.toLowerCase().contains(searchTerm) ??
                        false));

        // Filtros por categorías, subcategorías y marcas
        final matchesFilters = _selectedFilters.entries.every((entry) {
          if (entry.value.isEmpty) return true;
          final productValue = _getProductFilterValue(product, entry.key);
          return productValue != null && entry.value.contains(productValue);
        });

        return matchesSearch && matchesFilters;
      }).toList();
    });
  }

  int? _getProductFilterValue(Productos product, String filterType) {
    switch (filterType) {
      case 'categorias':
        return product.cate_Id;
      case 'subcategorias':
        return product.subc_Id;
      case 'marcas':
        return product.marc_Id;
      default:
        return null;
    }
  }

  void _toggleFilterSelection(String filterType, int value) {
    setState(() {
      final filters = _selectedFilters[filterType]!;
      if (filters.contains(value)) {
        filters.remove(value);
      } else {
        filters.add(value);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedFilters.forEach((key, value) => value.clear());
      _filteredProducts = List.from(_allProducts);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Productos',
        icon: Icons.inventory_2,
        // permisos: permisos,
        onRefresh: () async {
          await _loadProducts();
        },
        child: Column(
          children: [
            _buildSearchBar(), // Ahora incluye el ícono de filtrar
            _buildResultsCount(),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  // Bloque 2:  barra de búsqueda
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45, //altura del TextField
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF141A2F),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12, // Padding vertical reducido
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0), // Más redondeado
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(
                      color: Color(0xFF141A2F),
                      width: 2,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48, // Misma altura que el TextField
            width: 48, // Hacer el botón cuadrado
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                24,
              ), // Completamente redondeado
              border: Border.all(width: 1),
            ),
            child: IconButton(
              onPressed: _showFiltersPanel,
              icon: const Icon(Icons.filter_list, color: Color(0xFF141A2F)),
              tooltip: 'Filtrar',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showFiltersPanel,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filtrar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141A2F),
              foregroundColor: const Color(0xFFD6B68A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFiltersPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A2F),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Filtrar productos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Satoshi',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  _clearFilters();
                                  setModalState(
                                    () {},
                                  ); // Solo refrescar el modal
                                },
                                child: const Text('Limpiar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFD6B68A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _filtersLoaded
                              ? SingleChildScrollView(
                                  controller: scrollController,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildFilterSection(
                                          'Categorías',
                                          Icons.category,
                                          _categorias,
                                          'cate_Id',
                                          'cate_Descripcion',
                                          'categorias',
                                          setModalState,
                                        ),
                                        _buildFilterSection(
                                          'Subcategorías',
                                          Icons.list,
                                          _subcategorias,
                                          'subc_Id',
                                          'subc_Descripcion',
                                          'subcategorias',
                                          setModalState,
                                        ),
                                        _buildFilterSection(
                                          'Marcas',
                                          Icons.branding_watermark,
                                          _marcas,
                                          'marc_Id',
                                          'marc_Descripcion',
                                          'marcas',
                                          setModalState,
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _applyFilters(); // Aplicar filtros solo al confirmar
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Aplicar filtros',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF141A2F,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFFD6B68A),
                                              ),
                                              elevation: 0,
                                              foregroundColor: const Color(
                                                0xFFD6B68A,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFD6B68A),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterSection(
    String title,
    IconData icon,
    List<Map<String, dynamic>> items,
    String idKey,
    String nameKey,
    String filterType,
    StateSetter setModalState,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(
          0xFF141A2F,
        ), // Color ligeramente diferente para distinguir
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: const Color.fromARGB(255, 255, 255, 255),
              ),

              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.map((item) {
              final id = item[idKey] as int;
              final name = item[nameKey] as String? ?? 'Sin nombre';
              final isSelected =
                  _selectedFilters[filterType]?.contains(id) ?? false;

              return ChoiceChip(
                label: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(
                  0xFFD6B68A,
                ), //cuando está seleccionado
                backgroundColor: const Color(
                  0xFF141A2F,
                ), //  cuando no está seleccionado
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFD6B68A) : Colors.grey,
                  ),
                ),
                onSelected: (selected) {
                  _toggleFilterSelection(filterType, id);
                  setModalState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResultsCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Text(
            '${_filteredProducts.length} resultados',
            style: const TextStyle(color: Colors.grey),
          ),
          const Spacer(),
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Limpiar filtros'),
            ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters {
    return _searchController.text.isNotEmpty ||
        _selectedFilters.values.any((filter) => filter.isNotEmpty);
  }

  Widget _buildProductList() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_filteredProducts.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 50, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No se encontraron productos'),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Limpiar filtros'),
                ),
            ],
          ),
        ),
      );
    }

    // Generar los widgets de productos directamente para que funcionen con SingleChildScrollView
    return Column(
      children: _filteredProducts.map((product) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: _buildProductCard(product),
        );
      }).toList(),
    );
  }

  /// Bloque 1: Modificación de la Card del producto
  Widget _buildProductCard(Productos product) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ), // Más redondeada
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => _showProductDetail(product),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Imagen del producto mejorada
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _buildProductImage(product),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre del producto con flecha al lado
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.prod_Descripcion ?? 'Sin descripción',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Satoshi',
                              color: Color(0xFF141A2F),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF141A2F),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Marca
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.green[100]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            product.marc_Descripcion ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: 'Satoshi',
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue[100]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            product.cate_Descripcion ?? 'Sin categoría',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontFamily: 'Satoshi',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Precio
                    Text(
                      'L. ${product.prod_PrecioUnitario.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Satoshi',
                        color: Color(0xFF141A2F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetail(Productos product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: _buildProductDetailContent(
                        product,
                        scrollController,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductDetailContent(
    Productos product,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF141A2F),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFFD6B68A),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Detalle del producto',
                  style: TextStyle(
                    color: Color(0xFFD6B68A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: CachedNetworkImage(
                      imageUrl: product.prod_Imagen ?? '',
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  product.marc_Descripcion ?? 'MASTER',
                  style: const TextStyle(
                    fontSize: 26,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.prod_DescripcionCorta ?? 'PET MASTER',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    color: Color.fromARGB(255, 143, 141, 141),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Código:', product.prod_Codigo ?? 'N/A'),
                _buildDetailRow(
                  'Categoría:',
                  product.cate_Descripcion ?? 'No especificada',
                ),
                _buildDetailRow(
                  'Tipo:',
                  product.subc_Descripcion ?? 'No especificado',
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF141A2F),
                      foregroundColor: const Color(0xFFD6B68A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Solicitar recarga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                        color: Color(0xFFD6B68A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget mejorado para mostrar imágenes de productos con manejo robusto de errores
  Widget _buildProductImage(Productos product) {
    final imageUrl = product.prod_Imagen;
    
    // Si no hay URL de imagen, mostrar placeholder
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 32,
        ),
      );
    }
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('❌ Error cargando imagen: $url - Error: $error');
        return Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'Error',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
      // Configuración adicional para mejorar el rendimiento
      memCacheWidth: 160, // 2x el tamaño de display para pantallas de alta densidad
      memCacheHeight: 160,
      maxWidthDiskCache: 160,
      maxHeightDiskCache: 160,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: const Color.fromARGB(255, 0, 0, 0),
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
