import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/Offline_Services/Productos_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Recargas_OfflineService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/services/RecargasService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';
import 'package:sidcop_mobile/widgets/CachedProductImageWidget.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductosService _productosService = ProductosService();
  final ProductPreloadService _preloadService = ProductPreloadService();
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

  Future<void> _loadFilters() async {
    try {
      // Usar métodos que leen cache local primero
      final results = await Future.wait([
        ProductosOffline.obtenerCategoriasLocal(),
        ProductosOffline.obtenerSubcategoriasLocal(), 
        ProductosOffline.obtenerMarcasLocal(),
      ]);

      setState(() {
        _categorias = results[0];
        _subcategorias = results[1];
        _marcas = results[2];
        _filtersLoaded = true;
      });

      // Solo sincronizar en background si hay internet y los datos están vacíos
      if (_categorias.isEmpty || _subcategorias.isEmpty || _marcas.isEmpty) {
        debugPrint('Cache de filtros vacío, intentando sincronizar en background...');
        _sincronizarFiltrosEnBackground();
      }
    } catch (e) {
      debugPrint('Error cargando filtros: $e');
      setState(() {
        _filtersLoaded = true;
      });
    }
  }

  /// Sincroniza filtros en background sin bloquear la UI
  Future<void> _sincronizarFiltrosEnBackground() async {
    try {
      // Verificar conectividad antes de intentar sincronizar
      final hasConnection = await _verificarConexion();
      if (!hasConnection) {
        debugPrint('Sin conexión, no se pueden sincronizar filtros');
        return;
      }

      final results = await Future.wait([
        ProductosOffline.sincronizarCategorias(),
        ProductosOffline.sincronizarSubcategorias(),
        ProductosOffline.sincronizarMarcas(),
      ]);

      if (mounted) {
        setState(() {
          _categorias = results[0];
          _subcategorias = results[1]; 
          _marcas = results[2];
        });
        debugPrint('Filtros actualizados en background');
      }
    } catch (e) {
      debugPrint('Error sincronizando filtros en background: $e');
    }
  }

  /// Verifica conectividad simple
  Future<bool> _verificarConexion() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      // 1. Primero intentar cargar desde cache offline
      _allProducts = await ProductosOffline.obtenerProductosLocal();
      
      if (_allProducts.isNotEmpty) {
        debugPrint('Productos cargados desde cache offline: ${_allProducts.length}');
        setState(() {
          _filteredProducts = List.from(_allProducts);
          _isLoading = false;
        });
        
        // Verificar conectividad y sincronizar en background si es posible
        final hasConnection = await _verificarConexion();
        if (hasConnection) {
          _sincronizarProductosEnBackground();
        }
        return;
      }

      // 2. Si no hay cache, verificar conectividad antes de continuar
      final hasConnection = await _verificarConexion();
      
      if (hasConnection) {
        // Con conexión: intentar usar precarga o servicio directo
        _allProducts = await _preloadService.getPreloadedProducts();
        
        if (_allProducts.isNotEmpty) {
          debugPrint('Productos cargados desde precarga: ${_allProducts.length}');
          // Guardar en cache offline para próxima vez
          await ProductosOffline.guardarProductos(_allProducts);
        } else {
          // 3. Fallback: cargar directamente del servicio
          debugPrint('Cargando productos directamente del servicio...');
          _allProducts = await _productosService.getProductos();
          
          if (_allProducts.isNotEmpty) {
            // Guardar en cache offline
            await ProductosOffline.guardarProductos(_allProducts);
          }
        }
      } else {
        // Sin conexión y sin cache: mostrar mensaje apropiado
        debugPrint('Sin conexión y sin cache de productos');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      _filteredProducts = List.from(_allProducts);
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      // Último fallback: solo si hay conexión
      final hasConnection = await _verificarConexion();
      if (hasConnection) {
        try {
          _allProducts = await _productosService.getProductos();
          _filteredProducts = List.from(_allProducts);
        } catch (fallbackError) {
          debugPrint('Error en fallback de carga de productos: $fallbackError');
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Sincroniza productos en background sin bloquear la UI
  Future<void> _sincronizarProductosEnBackground() async {
    try {
      debugPrint('Sincronizando productos en background...');
      final nuevosProductos = await ProductosOffline.sincronizarProductos();
      
      if (nuevosProductos.isNotEmpty && mounted) {
        setState(() {
          _allProducts = nuevosProductos;
          _applyFilters(); // Reaplicar filtros con nuevos datos
        });
        debugPrint('Productos actualizados en background: ${nuevosProductos.length}');
      }
    } catch (e) {
      debugPrint('Error en sincronización background: $e');
    }
  }

  /// Método para refresh manual que fuerza sincronización
Future<void> _refreshData() async {
  try {
    setState(() => _isLoading = true);

    // Verificar conectividad antes de intentar sincronizar
    final hasConnection = await _verificarConexion();
    
    if (!hasConnection) {
      // Sin conexión: usar datos locales existentes
      debugPrint('Sin conexión, usando datos locales');
      
      final localData = await Future.wait([
        ProductosOffline.obtenerProductosLocal(),
        ProductosOffline.obtenerCategoriasLocal(),
        ProductosOffline.obtenerSubcategoriasLocal(),
        ProductosOffline.obtenerMarcasLocal(),
      ]);

      setState(() {
        if ((localData[0] as List<Productos>).isNotEmpty) {
          _allProducts = localData[0] as List<Productos>;
        }
        if ((localData[1] as List<Map<String, dynamic>>).isNotEmpty) {
          _categorias = localData[1] as List<Map<String, dynamic>>;
        }
        if ((localData[2] as List<Map<String, dynamic>>).isNotEmpty) {
          _subcategorias = localData[2] as List<Map<String, dynamic>>;
        }
        if ((localData[3] as List<Map<String, dynamic>>).isNotEmpty) {
          _marcas = localData[3] as List<Map<String, dynamic>>;
        }
        _applyFilters();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos actualizados desde cache local'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Con conexión: sincronizar desde servicios remotos
    final futures = <Future<dynamic>>[];
    
    futures.add(ProductosOffline.sincronizarProductos().catchError((e) {
      debugPrint('Error sincronizando productos: $e');
      return _allProducts; // Conservar productos existentes
    }));
    
    futures.add(ProductosOffline.sincronizarCategorias().catchError((e) {
      debugPrint('Error sincronizando categorías: $e');
      return _categorias; // Conservar categorías existentes
    }));
    
    futures.add(ProductosOffline.sincronizarSubcategorias().catchError((e) {
      debugPrint('Error sincronizando subcategorías: $e');
      return _subcategorias; // Conservar subcategorías existentes
    }));
    
    futures.add(ProductosOffline.sincronizarMarcas().catchError((e) {
      debugPrint('Error sincronizando marcas: $e');
      return _marcas; // Conservar marcas existentes
    }));

    final results = await Future.wait(futures);

    setState(() {
      // Solo actualizar si hay datos válidos
      if (results[0] is List<Productos> && (results[0] as List).isNotEmpty) {
        _allProducts = results[0] as List<Productos>;
      }
      if (results[1] is List<Map<String, dynamic>> && (results[1] as List).isNotEmpty) {
        _categorias = results[1] as List<Map<String, dynamic>>;
      }
      if (results[2] is List<Map<String, dynamic>> && (results[2] as List).isNotEmpty) {
        _subcategorias = results[2] as List<Map<String, dynamic>>;
      }
      if (results[3] is List<Map<String, dynamic>> && (results[3] as List).isNotEmpty) {
        _marcas = results[3] as List<Map<String, dynamic>>;
      }
      
      _applyFilters();
      _isLoading = false;
    });

    debugPrint('Datos actualizados desde servicios remotos');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos sincronizados correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error en refresh: $e');
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar datos: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
// ...existing code...

  void _applyFilters() {
    final searchTerm = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Filtro por búsqueda
        final matchesSearch =
            searchTerm.isEmpty ||
            (product.prod_Descripcion?.toLowerCase().contains(searchTerm) ??
                false) ||
            (product.prod_Codigo?.toLowerCase().contains(searchTerm) ?? false);

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
        onRefresh: _refreshData, // Usar método que fuerza sincronización
        child: Column(
          children: [
            _buildSearchBar(),
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
                  );
                },
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
              Icon(icon, size: 20, color: Colors.white),
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
                selectedColor: const Color(0xFFD6B68A),
                backgroundColor: const Color(0xFF141A2F),
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
              CachedProductImageWidget(
                product: product,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8.0),
                showPlaceholder: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(
                      'L. ${product.prod_PrecioUnitario.toStringAsFixed(2)}',
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
                    child: Image.network(
                      product.prod_Imagen ?? '',
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
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
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.prod_DescripcionCorta ?? 'PET MASTER',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    color: Colors.grey,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cierra el modal de detalle
                      _openRecargaModal(product); // Abre el modal de recarga
                    },
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

  void _openRecargaModal(Productos product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _RecargaBottomSheetWrapper(initialProduct: product);
        },
      ),
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
              style: const TextStyle(
                color: Colors.black,
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

class _RecargaBottomSheetWrapper extends StatefulWidget {
  final Productos initialProduct;

  const _RecargaBottomSheetWrapper({required this.initialProduct});

  @override
  State<_RecargaBottomSheetWrapper> createState() =>
      _RecargaBottomSheetWrapperState();
}

class _RecargaBottomSheetWrapperState
    extends State<_RecargaBottomSheetWrapper> {
  final ProductosService _productosService = ProductosService();
  final RecargasService _recargasService = RecargasService();
  final PerfilUsuarioService _perfilService = PerfilUsuarioService();

  List<Productos> _productos = [];
  Map<int, int> _cantidades = {};
  Map<int, TextEditingController> _controllers = {};
  String search = '';
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _cantidades[widget.initialProduct.prod_Id] = 1;
    _fetchProductos();
    if (!_isSyncing) {
      _sincronizarRecargasPendientes();
    }
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none && !_isSyncing) {
        await _sincronizarRecargasPendientes();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _sincronizarRecargasPendientes() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final connectivityResult = await Connectivity().checkConnectivity();
    final online = connectivityResult != ConnectivityResult.none;
    if (!online) {
      _isSyncing = false;
      return;
    }

    try {
      final pendientesRaw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
      if (pendientesRaw == null || pendientesRaw.isEmpty) {
        _isSyncing = false;
        return;
      }

      final pendientes = List<Map<String, dynamic>>.from(pendientesRaw);
      final recargaService = RecargasService();

      int sincronizadas = 0;
      final recargasNoSincronizadas = <Map<String, dynamic>>[];

      for (final recarga in pendientes) {
        try {
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          final usuaId = recarga['usua_Id'];

          final success = await recargaService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );

          if (success) {
            sincronizadas++;
          } else {
            recargasNoSincronizadas.add(recarga);
          }
        } catch (e) {
          recargasNoSincronizadas.add(recarga);
          debugPrint('Error al sincronizar recarga: $e');
        }
      }

      await RecargasScreenOffline.guardarJson('recargas_pendientes.json', recargasNoSincronizadas);

      if (mounted && sincronizadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sincronizadas recarga(s) sincronizada(s) con éxito'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al sincronizar recargas pendientes: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _fetchProductos() async {
    bool online = true;
    try {
      final result = await InternetAddress.lookup('google.com');
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    if (online) {
      try {
        final productos = await _productosService.getProductos();
        setState(() {
          _productos = productos;
          _isLoading = false;
        });
        // Guardar productos offline
        try {
          final jsonList = productos.map((p) => p.toJson()).toList();
          await RecargasScreenOffline.guardarJson('productos.json', jsonList);
        } catch (_) {}
      } catch (e) {
        await _loadProductosOffline();
      }
    } else {
      await _loadProductosOffline();
    }
  }

  Future<void> _loadProductosOffline() async {
    try {
      final raw = await RecargasScreenOffline.leerJson('productos.json');
      if (raw != null) {
        final lista = List.from(raw as List);
        setState(() {
          _productos = lista.map((json) => Productos.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _productos = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _productos = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _productos.where((p) {
      final nombre = (p.prod_DescripcionCorta ?? '').toLowerCase();
      return nombre.contains(search.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF475569)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Solicitud de recarga',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontFamily: 'Satoshi',
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Products list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                      ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No se encontraron productos',
                                style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final producto = filtered[i];
                            final cantidad = _cantidades[producto.prod_Id] ?? 0;
                            return _buildProducto(producto, cantidad);
                          },
                        ),
            ),
            
            // Submit button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141A2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    // Get logged user
                    final userData = await _perfilService.obtenerDatosUsuario();
                    if (userData == null || userData['usua_Id'] == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("No se pudo obtener el usuario logueado."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final int usuaId = userData['usua_Id'] is String
                        ? int.tryParse(userData['usua_Id']) ?? 0
                        : userData['usua_Id'] ?? 0;

                    if (usuaId == 0) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("ID de usuario inválido."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    // Build details
                    final detalles = _cantidades.entries
                        .where((e) => e.value > 0)
                        .map(
                          (e) => {
                            "prod_Id": e.key,
                            "reDe_Cantidad": e.value,
                            "reDe_Observaciones": "N/A",
                          },
                        )
                        .toList();

                    // Validate quantities
                    for (var detalle in detalles) {
                      if (int.tryParse(detalle['reDe_Cantidad'].toString())! > 99) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("La cantidad máxima es 99."),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    if (detalles.isEmpty) {
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Alerta!'),
                              content: const Text('Selecciona al menos un producto.'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                      return;
                    }

                    // Check connectivity
                    bool online = true;
                    try {
                      final result = await InternetAddress.lookup('google.com');
                      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
                    } catch (_) {
                      online = false;
                    }

                    bool ok = false;
                    if (online) {
                      // Call RecargasService
                      ok = await _recargasService.insertarRecarga(
                        usuaCreacion: usuaId,
                        detalles: detalles,
                      );
                    } else {
                      // Save offline for later sync
                      final recargaOffline = {
                        'id': DateTime.now().microsecondsSinceEpoch,
                        'usua_Id': usuaId,
                        'detalles': detalles,
                        'fecha': DateTime.now().toIso8601String(),
                        'offline': true,
                      };
                      try {
                        final raw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
                        List<dynamic> pendientes = raw != null ? List.from(raw as List) : [];
                        pendientes.add(recargaOffline);
                        await RecargasScreenOffline.guardarJson('recargas_pendientes.json', pendientes);
                        ok = true;
                      } catch (e) {
                        ok = false;
                      }
                    }

                    // Try to sync pending recharges
                    await _sincronizarRecargasPendientes();

                    if (mounted) {
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(online
                                ? "Recarga enviada correctamente"
                                : "Recarga guardada en modo offline. Se enviará cuando haya conexión."),
                            backgroundColor: online ? Colors.green : Colors.orange,
                          ),
                        );
                        Navigator.of(context).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(online
                                ? "Error al enviar la recarga"
                                : "Error al guardar la recarga offline"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  label: const Text(
                    'Solicitar recarga',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducto(Productos producto, int cantidad) {
    // Initialize controller if it doesn't exist
    if (!_controllers.containsKey(producto.prod_Id)) {
      final controller = TextEditingController(
        text: cantidad > 0 ? cantidad.toString() : '',
      );
      controller.addListener(() {
        final text = controller.text;
        final value = int.tryParse(text);
        if (value != null && value >= 0 && value <= 99) {
          setState(() {
            _cantidades[producto.prod_Id] = value;
          });
        } else if (text.isEmpty) {
          setState(() {
            _cantidades[producto.prod_Id] = 0;
          });
        }
      });
      _controllers[producto.prod_Id] = controller;
    } else {
      // Update controller text if quantity changed
      final currentText = _controllers[producto.prod_Id]!.text;
      final text = cantidad > 0 ? cantidad.toString() : '';
      if (currentText != text) {
        _controllers[producto.prod_Id]!.text = text;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F172A).withOpacity(0.08),
                  const Color(0xFF0F172A).withOpacity(0.12),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: producto.prod_Imagen != null && producto.prod_Imagen!.isNotEmpty
                  ? Image.network(
                      producto.prod_Imagen!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.inventory_2_rounded,
                          color: const Color(0xFF0F172A).withOpacity(0.6),
                          size: 32,
                        );
                      },
                    )
                  : Icon(
                      Icons.inventory_2_rounded,
                      color: const Color(0xFF0F172A).withOpacity(0.6),
                      size: 32,
                    ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.prod_DescripcionCorta ?? 'Producto',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (producto.marc_Descripcion != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      producto.marc_Descripcion!,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cantidad > 0 ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cantidad > 0 ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.remove_rounded,
                    color: cantidad > 0 ? Colors.white : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: cantidad > 0
                      ? () {
                          final newValue = cantidad - 1;
                          _controllers[producto.prod_Id]?.text = newValue > 0
                              ? newValue.toString()
                              : '';
                          setState(() {
                            _cantidades[producto.prod_Id] = newValue;
                          });
                        }
                      : null,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Container(
                width: 60,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controllers[producto.prod_Id],
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cantidad < 99 ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cantidad < 99 ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.add_rounded,
                    color: cantidad < 99 ? Colors.white : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: cantidad < 99
                      ? () {
                          final newValue = cantidad + 1;
                          _controllers[producto.prod_Id]?.text = newValue.toString();
                          setState(() {
                            _cantidades[producto.prod_Id] = newValue;
                          });
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
