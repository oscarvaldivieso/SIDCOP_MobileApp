import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/models/ProductosPedidosViewModel.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/pedidos_confirmar_screen.dart';
import 'package:sidcop_mobile/utils/numero_en_letras.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';

class PedidosCreateScreen extends StatefulWidget {
  final int clienteId;
  const PedidosCreateScreen({Key? key, required this.clienteId})
    : super(key: key);

  @override
  State<PedidosCreateScreen> createState() => _PedidosCreateScreenState();
}

class _PedidosCreateScreenState extends State<PedidosCreateScreen> {
  DateTime? _fechaEntrega;
  List<ProductosPedidosViewModel> _productos = [];
  List<DescuentoEscalaModel> _descuentos = [];
  List<ProductosPedidosViewModel> _filteredProductos = [];
  final Map<int, int> _cantidades = {};
  final Map<int, int?> _descuentosSeleccionados =
      {}; // prodId -> índice del descuento seleccionado (null = ninguno)
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  int _productosMostrados = 8;

  // Variables para direcciones
  List<dynamic> _direcciones = [];
  dynamic _direccionSeleccionada;
  bool _loadingDirecciones = false;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
    _fetchDirecciones();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProductos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final isSearching = _searchController.text.trim().isNotEmpty;
    final productosParaMostrar = isSearching
        ? _filteredProductos
        : _filteredProductos.take(_productosMostrados).toList();

    final listView = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: productosParaMostrar.length,
      itemBuilder: (context, index) {
        return _buildProductoItem(productosParaMostrar[index]);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 16),

        // Header de productos seleccionados si hay al menos uno
        if (_hasSelectedProducts()) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0C7A0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  color: Color(0xFF141A2F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Productos Seleccionados',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A2F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0C7A0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_cantidades.values.where((c) => c > 0).fold<int>(0, (sum, c) => sum + c)} items',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141A2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        _filteredProductos.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'No se encontraron productos que coincidan con la búsqueda',
                  textAlign: TextAlign.center,
                ),
              )
            : listView,
        if (!isSearching && _productosMostrados < _filteredProductos.length)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0, right: 4.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _productosMostrados += 8;
                  });
                },
                icon: const Icon(Icons.expand_more),
                label: const Text('Ver más'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF141A2F), // color principal
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProductos = List.from(_productos);
        _productosMostrados = 8; // Reiniciar paginación
      } else {
        _filteredProductos = _productos.where((producto) {
          final nombre = producto.prodDescripcionCorta?.toLowerCase() ?? '';
          return nombre.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchProductos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final productos = await PedidosService().getProductosConListaPrecio(
        widget.clienteId,
      );
      print(productos[3].toJson());
      //print(productos[3].descuentosEscala![0].toJson());
      setState(() {
        _productos = productos;
        _filteredProductos = List.from(_productos);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar productos $e';
      });
    }
  }

  Future<void> _fetchDirecciones() async {
    setState(() {
      _loadingDirecciones = true;
    });
    try {
      final direcciones = await ClientesService().getDireccionesCliente(
        widget.clienteId,
      );

      // Debug: Imprimir estructura de direcciones
      print('Direcciones obtenidas: $direcciones');
      if (direcciones.isNotEmpty) {
        print('Primera dirección: ${direcciones[0]}');
        print('Claves de primera dirección: ${direcciones[0].keys.toList()}');
      }

      setState(() {
        _direcciones = direcciones;
        _loadingDirecciones = false;
        // Seleccionar la primera dirección por defecto si existe
        if (_direcciones.isNotEmpty) {
          _direccionSeleccionada = _direcciones[0];
          print('Dirección seleccionada por defecto: $_direccionSeleccionada');
        }
      });
    } catch (e) {
      setState(() {
        _loadingDirecciones = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar direcciones: $e')),
        );
      }
    }
  }

  Future<void> _selectFechaEntrega(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        // locale: const Locale('es', 'ES'), // Quitar si da error
      );
      if (picked != null) {
        setState(() {
          _fechaEntrega = picked;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar fecha: \\${e.toString()}'),
        ),
      );
    }
  }

  num _getPrecioPorCantidad(ProductosPedidosViewModel producto, int cantidad) {
    // 1. Obtener el precio base según escala
    num precioBase;
    if (producto.listasPrecio != null &&
        producto.listasPrecio!.isNotEmpty &&
        cantidad > 0) {
      ListaPrecioModel? ultimaEscala;
      for (final lp in producto.listasPrecio!) {
        if (cantidad >= lp.prePInicioEscala && cantidad <= lp.prePFinEscala) {
          precioBase = lp.prePPrecioContado;
          return _aplicarDescuento(producto, cantidad, precioBase);
        }
        ultimaEscala = lp;
      }
      if (ultimaEscala != null && cantidad > ultimaEscala.prePFinEscala) {
        precioBase = ultimaEscala.prePPrecioContado;
        return _aplicarDescuento(producto, cantidad, precioBase);
      }
    }
    precioBase = producto.prodPrecioUnitario ?? 0;
    return _aplicarDescuento(producto, cantidad, precioBase);
  }

  num _aplicarDescuento(
    ProductosPedidosViewModel producto,
    int cantidad,
    num precioBase,
  ) {
    // Solo aplicar descuento si hay uno seleccionado manualmente
    final indiceDescuentoSeleccionado =
        _descuentosSeleccionados[producto.prodId];
    if (indiceDescuentoSeleccionado != null &&
        producto.descuentosEscala != null &&
        indiceDescuentoSeleccionado < producto.descuentosEscala!.length) {
      final descEsp = producto.descEspecificaciones;
      if (descEsp != null && descEsp.descTipoFactura == 'AM') {
        final descuentoSeleccionado =
            producto.descuentosEscala![indiceDescuentoSeleccionado];
        return _calcularDescuento(
          precioBase,
          descEsp,
          descuentoSeleccionado.deEsValor,
        );
      }
    }

    // Si no hay descuento seleccionado manualmente, devolver precio base sin descuento
    return precioBase;
  }

  num _calcularDescuento(
    num precioBase,
    DescEspecificacionesModel descEsp,
    num valorDescuento,
  ) {
    if (descEsp.descTipo == 0) {
      // Porcentaje
      return precioBase - (precioBase * (valorDescuento / 100));
    } else if (descEsp.descTipo == 1) {
      // Cantidad fija
      return precioBase - valorDescuento;
    }
    return precioBase;
  }

  // Verificar si hay productos seleccionados
  bool _hasSelectedProducts() {
    return _cantidades.values.any((cantidad) => cantidad > 0);
  }

  Future<void> _navegarASiguientePantalla() async {
    // 1. Validar productos seleccionados
    final productosSeleccionados = _cantidades.entries
        .where((e) => e.value > 0)
        .toList();
    if (productosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona al menos un producto con cantidad mayor a cero.',
          ),
        ),
      );
      return;
    }
    // 2. Validar fecha de entrega
    if (_fechaEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha de entrega.')),
      );
      return;
    }
    // 3. Validar dirección seleccionada
    if (_direccionSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una dirección de entrega.')),
      );
      return;
    }

    // Verificar conexión a internet
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = connectivityResult != ConnectivityResult.none;

    // 4. Preparar productos para confirmación
    final productosSeleccionadosList = _cantidades.entries
        .where((e) => e.value > 0)
        .toList();

    // Mapear productos seleccionados al formato requerido
    final List<Map<String, dynamic>> detallesPedido = [];
    double totalPedido = 0;

    for (final entry in productosSeleccionadosList) {
      final producto = _productos.firstWhere((p) => p.prodId == entry.key);
      final cantidad = entry.value;
      final precioUnitario = _getPrecioPorCantidad(producto, cantidad);
      
      detallesPedido.add({
        'prodId': producto.prodId,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'descuento': 0, // Ajustar según sea necesario
      });
      
      totalPedido += precioUnitario * cantidad;
    }

    // Obtener datos del usuario actual
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    final int? vendedorId = userData?['usua_IdPersona'] is String
        ? int.tryParse(userData?['usua_IdPersona'])
        : userData?['usua_IdPersona'];

    // Crear objeto de pedido para guardar offline
    final pedidoOffline = {
      'clienteId': widget.clienteId,
      'vendedorId': vendedorId,
      'fechaPedido': DateTime.now().toIso8601String(),
      'fechaEntrega': _fechaEntrega!.toIso8601String(),
      'direccionId': _direccionSeleccionada['diCl_Id'],
      'total': totalPedido,
      'estado': isOnline ? 'Pendiente' : 'Pendiente Sincronización',
      'detalles': detallesPedido,
    };

    // Si no hay conexión, guardar el pedido localmente
    if (!isOnline) {
      try {
        await PedidosScreenOffline.guardarPedidoPendiente(pedidoOffline);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido guardado localmente. Se sincronizará cuando haya conexión.'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(); // Volver a la pantalla anterior
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar el pedido: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Si hay conexión o se está en modo offline, continuar con el flujo normal
    final productosConfirmacion = productosSeleccionadosList.map((e) {
      final producto = _productos.firstWhere((p) => p.prodId == e.key);
      final precioFinal = _getPrecioPorCantidad(producto, e.value);
      return ProductoConfirmacion(
        prodId: producto.prodId,
        nombre: producto.prodDescripcionCorta ?? '',
        cantidad: e.value,
        precioBase: producto.prodPrecioUnitario ?? 0,
        precioFinal: precioFinal,
        imagen: producto.prodImagen,
        productoOriginal: producto,
      );
    }).toList();

    // 5. Calcular totales
    final cantidadTotal = productosConfirmacion.fold<int>(
      0,
      (sum, p) => sum + p.cantidad,
    );
    final subtotal = productosConfirmacion.fold<num>(
      0,
      (sum, p) => sum + (p.precioBase * p.cantidad),
    );
    final total = productosConfirmacion.fold<num>(
      0,
      (sum, p) => sum + (p.precioFinal * p.cantidad),
    );

    // 6. Navegar a pantalla de confirmación
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PedidoConfirmarScreen(
            productosSeleccionados: productosConfirmacion,
            cantidadTotal: cantidadTotal,
            subtotal: subtotal,
          total: total,
          clienteId: widget.clienteId,
          fechaEntrega: _fechaEntrega!,
          direccionSeleccionada: _direccionSeleccionada!,
        ),
      ),
    );
  }}

  Widget _buildDescuentosItem(
    ProductosPedidosViewModel producto,
    DescuentoEscalaModel descuento,
    int indiceDescuento,
  ) {
    final isSelected =
        _descuentosSeleccionados[producto.prodId] == indiceDescuento;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFE0C7A0).withOpacity(0.2)
            : const Color(0xFFE0C7A0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF98774A)
              : const Color(0xFFE0C7A0).withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_descuentosSeleccionados[producto.prodId] == indiceDescuento) {
              // Si ya está seleccionado, deseleccionar
              _descuentosSeleccionados[producto.prodId] = null;
            } else {
              // Seleccionar este descuento
              _descuentosSeleccionados[producto.prodId] = indiceDescuento;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Radio button personalizado
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF98774A) : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected
                      ? const Color(0xFF98774A)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.local_offer,
                color: isSelected ? const Color(0xFF98774A) : Colors.grey[600],
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desde ${descuento.deEsInicioEscala} hasta ${descuento.deEsFinEscala} unidades: ${descuento.deEsValor}% descuento',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF141A2F)
                        : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductoItem(ProductosPedidosViewModel producto) {
    final cantidad = _cantidades[producto.prodId] ?? 0;
    final isSelected = cantidad > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFD6B68A).withOpacity(0.1),
                ],
              )
            : null,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF98774A)
              : const Color(0xFF262B40).withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF98774A).withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 12 : 10,
            offset: Offset(0, isSelected ? 4 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen del producto con mejor diseño
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF262B40).withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF262B40).withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child:
                              producto.prodImagen != null &&
                                  producto.prodImagen!.isNotEmpty
                              ? Image.network(
                                  producto.prodImagen!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(
                                                0xFFD6B68A,
                                              ).withOpacity(0.2),
                                              const Color(
                                                0xFF98774A,
                                              ).withOpacity(0.1),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Color(0xFF98774A),
                                          size: 28,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(
                                          0xFFD6B68A,
                                        ).withOpacity(0.2),
                                        const Color(
                                          0xFF98774A,
                                        ).withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Color(0xFF98774A),
                                    size: 28,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Información del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              producto.prodDescripcionCorta ??
                                  'Sin descripción',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Color(0xFF262B40)
                                    : Color(0xFF262B40),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'L. ${_getPrecioPorCantidad(producto, cantidad).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF141A2F),
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subtotal: L. ${(_getPrecioPorCantidad(producto, cantidad) * cantidad).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF98774A),
                                      ),
                                    ),
                                    // Indicador de descuento manual seleccionado
                                    if (_descuentosSeleccionados[producto
                                            .prodId] !=
                                        null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.local_offer,
                                              size: 12,
                                              color: const Color(0xFF98774A),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Descuento manual aplicado',
                                              style: const TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF98774A),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Controles de cantidad mejorados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón de deseleccionar cuando está seleccionado
                      if (isSelected)
                        GestureDetector(
                          onTap: () => setState(() {
                            _cantidades[producto.prodId] = 0;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE74C3C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE74C3C).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.remove_circle_outline,
                                  color: Color(0xFFE74C3C),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Quitar',
                                  style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 12,
                                    color: const Color(0xFFE74C3C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox(),
                      // Controles de cantidad con mejor diseño
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF262B40).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF98774A)
                                : const Color(0xFF262B40).withOpacity(0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cantidad > 0
                                    ? const Color(0xFF262B40)
                                    : const Color(0xFF262B40).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                onPressed: cantidad > 0
                                    ? () => setState(() {
                                        _cantidades[producto.prodId] =
                                            cantidad - 1;
                                      })
                                    : null,
                                icon: const Icon(Icons.remove, size: 18),
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final TextEditingController controller =
                                    TextEditingController(
                                      text: cantidad.toString(),
                                    );

                                final result = await showDialog<int>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      'Cantidad',
                                      style: TextStyle(fontFamily: 'Satoshi'),
                                    ),
                                    content: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        hintText: 'Ingrese la cantidad',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) {
                                        final value =
                                            int.tryParse(controller.text) ?? 0;
                                        Navigator.of(context).pop(value);
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final value =
                                              int.tryParse(controller.text) ??
                                              0;
                                          Navigator.of(context).pop(value);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF98774A,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text(
                                          'Aceptar',
                                          style: TextStyle(
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (result != null && result >= 0) {
                                  setState(() {
                                    _cantidades[producto.prodId] = result;
                                  });
                                }
                              },
                              child: Container(
                                width: 50,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD6B68A).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    cantidad.toString(),
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? const Color(0xFF262B40)
                                          : const Color(
                                              0xFF262B40,
                                            ).withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF98774A),
                                    const Color(0xFFD6B68A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF98774A,
                                    ).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => setState(() {
                                  _cantidades[producto.prodId] = cantidad + 1;
                                }),
                                icon: const Icon(Icons.add, size: 18),
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Mostrar descuentos si existen
                  if (producto.descuentosEscala != null &&
                      producto.descuentosEscala!.isNotEmpty)
                    Container(
                      child: ExpansionTile(
                        title: Text(
                          'Descuentos de Precio (${producto.descuentosEscala!.length})',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A2F),
                          ),
                        ),
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: producto.descuentosEscala!
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _buildDescuentosItem(
                                      producto,
                                      entry.value,
                                      entry.key,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Indicador de producto impulsado (punto verde)
            if (producto.prod_Impulsado)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            // Indicador visual de selección en la esquina
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF98774A),
                        const Color(0xFFD6B68A),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ),
            // Faja de promoción si el producto es promo
            if (producto.prodEsPromo == 'S')
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'PROMO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Satoshi',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: const CustomDrawer(permisos: []),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F6F6), Color(0xFFF6F6F6)],
          ),
        ),
        child: Column(
          children: [
            // Header similar to AppBackground
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.03,
                left: 16,
                right: 16,
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Container(
                  color: const Color(0xFF141A2F),
                  child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.10,
                    child: Stack(
                      children: [
                        // Título alineado a la izquierda y centrado verticalmente
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Text(
                              'Nuevo Pedido',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Satoshi',
                                  ),
                            ),
                          ),
                        ),
                        // Icono alineado a la esquina inferior derecha
                        Positioned(
                          bottom: 12,
                          right: 18,
                          child: Icon(
                            Icons.add_shopping_cart,
                            color: const Color(0xFFE0C7A0),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Contenido scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona fecha de entrega:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectFechaEntrega(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 19,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _fechaEntrega != null
                                    ? '${_fechaEntrega!.day.toString().padLeft(2, '0')}/${_fechaEntrega!.month.toString().padLeft(2, '0')}/${_fechaEntrega!.year}'
                                    : 'Elegir fecha',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _fechaEntrega != null
                                      ? Colors.black
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown de direcciones
                      Text(
                        'Selecciona dirección de entrega:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _loadingDirecciones
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _direcciones.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 19,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'No hay direcciones disponibles',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<dynamic>(
                                  value: _direccionSeleccionada,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey.shade600,
                                  ),
                                  items: _direcciones
                                      .map<DropdownMenuItem<dynamic>>((
                                        direccion,
                                      ) {
                                        final descripcion =
                                            direccion['diCl_DireccionExacta'] ??
                                            direccion['DiCl_DireccionExacta'] ??
                                            direccion['descripcion'] ??
                                            'Dirección sin descripción';
                                        return DropdownMenuItem<dynamic>(
                                          value: direccion,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 19,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  descripcion,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _direccionSeleccionada = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                      const SizedBox(height: 24),
                      Text(
                        'Selecciona productos y cantidades:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProductList(),
                      // Padding at bottom to prevent overlap with fixed button
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _navegarASiguientePantalla,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFFE0C7A0,
                ), // Color dorado del proyecto
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Siguiente'),
            ),
          ),
        ),
      ),
    );
  }
}
