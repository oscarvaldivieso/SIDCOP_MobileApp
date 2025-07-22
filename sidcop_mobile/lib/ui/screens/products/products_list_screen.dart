import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';

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
    _searchController.addListener(_applyFilters);
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _allProducts = await _productosService.getProductos();
      _filteredProducts = List.from(_allProducts);
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      setState(() => _isLoading = false);
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
      _applyFilters();
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
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFiltersPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildResultsCount(),
          _buildProductList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
        ),
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
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Filtrar productos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Limpiar'),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: FutureBuilder(
                        future: Future.wait([
                          _productosService.getCategorias(),
                          _productosService.getSubcategorias(),
                          _productosService.getMarcas(),
                        ]),
                        builder:
                            (context, AsyncSnapshot<List<dynamic>> snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text('Error al cargar filtros'),
                                );
                              }

                              final categorias =
                                  snapshot.data?[0]
                                      as List<Map<String, dynamic>>? ??
                                  [];
                              final subcategorias =
                                  snapshot.data?[1]
                                      as List<Map<String, dynamic>>? ??
                                  [];
                              final marcas =
                                  snapshot.data?[2]
                                      as List<Map<String, dynamic>>? ??
                                  [];

                              return SingleChildScrollView(
                                controller: scrollController,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildFilterSection(
                                        'Categorías',
                                        Icons.category,
                                        categorias,
                                        'cate_Id',
                                        'cate_Descripcion',
                                        'categorias',
                                      ),

                                      _buildFilterSection(
                                        'Subcategorías',
                                        Icons.list,
                                        subcategorias,
                                        'subc_Id',
                                        'subc_Descripcion',
                                        'subcategorias',
                                      ),

                                      _buildFilterSection(
                                        'Marcas',
                                        Icons.branding_watermark,
                                        marcas,
                                        'marc_Id',
                                        'marc_Descripcion',
                                        'marcas',
                                      ),

                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _applyFilters();
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Aplicar filtros'),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              );
                            },
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

  Widget _buildFilterSection(
    String title,
    IconData icon,
    List<Map<String, dynamic>> items,
    String idKey,
    String nameKey,
    String filterType,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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
              label: Text(name),
              selected: isSelected,
              onSelected: (selected) => _toggleFilterSelection(filterType, id),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
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
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_filteredProducts.isEmpty) {
      return Expanded(
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

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  //La tarjetita de los productos
  Widget _buildProductCard(Productos product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: () => _showProductDetail(product),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  product.prod_Imagen ?? '',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.prod_Descripcion ?? 'Sin descripción',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.marc_Descripcion ?? '',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.cate_Descripcion ?? '',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'L. ${product.prod_PrecioUnitario.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  //Detalle del producto
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.prod_Descripcion ?? 'PET MASTER',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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
                    color: Colors.green[50],
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
                    child: const Text('Solicitar recarga'),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                fontWeight: FontWeight.w500,
                color: Colors.grey,
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
