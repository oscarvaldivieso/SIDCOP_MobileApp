import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/pedido_Confirmar_screen.dart';
import 'package:sidcop_mobile/models/ProductosPedidosViewModel.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';

class PedidosCreateScreen extends StatefulWidget {
  final int clienteId;
  const PedidosCreateScreen({Key? key, required this.clienteId}) : super(key: key);

  @override
  State<PedidosCreateScreen> createState() => _PedidosCreateScreenState();
}

class _PedidosCreateScreenState extends State<PedidosCreateScreen> {
  DateTime? _fechaEntrega;
  List<ProductosPedidosViewModel> _productos = [];
  List<ProductosPedidosViewModel> _filteredProductos = [];
  final Map<int, int> _cantidades = {};
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  int _productosMostrados = 8;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
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
        _filteredProductos.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text('No se encontraron productos que coincidan con la búsqueda',
                    textAlign: TextAlign.center),
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
      final productos = await PedidosService().getProductosConListaPrecio(widget.clienteId);
      setState(() {
        _productos = productos;
        _filteredProductos = List.from(_productos);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar productos';
      });
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
      SnackBar(content: Text('Error al seleccionar fecha: \\${e.toString()}')),
    );
  }
}


  num _getPrecioPorCantidad(ProductosPedidosViewModel producto, int cantidad) {
    // 1. Obtener el precio base según escala
    num precioBase;
    if (producto.listasPrecio != null && producto.listasPrecio!.isNotEmpty && cantidad > 0) {
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

  num _aplicarDescuento(ProductosPedidosViewModel producto, int cantidad, num precioBase) {
    // 2. Verificar si hay descuentos y si aplica
    if (producto.descuentosEscala == null || producto.descuentosEscala!.isEmpty) {
      return precioBase;
    }
    final descEsp = producto.descEspecificaciones;
    if (descEsp == null || descEsp.descTipoFactura != 'AM') {
      return precioBase;
    }
    // Buscar el descuento correspondiente
    DescuentoEscalaModel? ultimoDescuento;
    for (final desc in producto.descuentosEscala!) {
      if (cantidad >= desc.deEsInicioEscala && cantidad <= desc.deEsFinEscala) {
        return _calcularDescuento(precioBase, descEsp, desc.deEsValor);
      }
      ultimoDescuento = desc;
    }
    // Si la cantidad es mayor al último rango, usar el último descuento
    if (ultimoDescuento != null && cantidad > ultimoDescuento.deEsFinEscala) {
      return _calcularDescuento(precioBase, descEsp, ultimoDescuento.deEsValor);
    }
    return precioBase;
  }

  num _calcularDescuento(num precioBase, DescEspecificacionesModel descEsp, num valorDescuento) {
    if (descEsp.descTipo == 0) {
      // Porcentaje
      return precioBase - (precioBase * (valorDescuento / 100));
    } else if (descEsp.descTipo == 1) {
      // Cantidad fija
      return precioBase - valorDescuento;
    }
    return precioBase;
  }

  Widget _buildProductoItem(ProductosPedidosViewModel producto) {
    final cantidad = _cantidades[producto.prodId] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (producto.prodImagen != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  producto.prodImagen!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                ),
              )
            else
              const Icon(Icons.image, size: 40, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.prodDescripcionCorta ?? 'Sin descripción',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Precio: L. ${_getPrecioPorCantidad(producto, cantidad).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: cantidad > 0
                      ? () {
                          setState(() {
                            _cantidades[producto.prodId] = cantidad - 1;
                          });
                        }
                      : null,
                ),
                SizedBox(
                  width: 38,
                  child: TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: cantidad.toString()),
                    onChanged: (val) {
                      final value = int.tryParse(val) ?? 0;
                      setState(() {
                        _cantidades[producto.prodId] = value;
                      });
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() {
                      _cantidades[producto.prodId] = cantidad + 1;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Nuevo Pedido',
      icon: Icons.add_shopping_cart,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selecciona fecha de entrega:', 
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectFechaEntrega(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 19, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text(
                        _fechaEntrega != null
                            ? '${_fechaEntrega!.day.toString().padLeft(2, '0')}/${_fechaEntrega!.month.toString().padLeft(2, '0')}/${_fechaEntrega!.year}'
                            : 'Elegir fecha',
                        style: TextStyle(fontSize: 15, color: _fechaEntrega != null ? Colors.black : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Selecciona productos y cantidades:', 
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              _buildProductList(),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final productosSeleccionados = _productos.where((p) => (_cantidades[p.prodId] ?? 0) > 0).toList();
                    if (productosSeleccionados.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un producto.')));
                      return;
                    }

                    // Construir la lista para la pantalla de confirmación
                    final List<ProductoConfirmacion> listaConfirmacion = productosSeleccionados.map((p) {
                      final cantidad = _cantidades[p.prodId] ?? 0;
                      final precioBase = _getPrecioPorCantidad(p, cantidad);
                      final precioFinal = _getPrecioPorCantidad(p, cantidad);
                      return ProductoConfirmacion(
                        nombre: p.prodDescripcionCorta ?? '',
                        cantidad: cantidad,
                        precioBase: precioBase,
                        precioFinal: precioFinal,
                        imagen: p.prodImagen,
                      );
                    }).toList();

                    final cantidadTotal = listaConfirmacion.fold<int>(0, (s, p) => s + p.cantidad);
                    final subtotal = listaConfirmacion.fold<num>(0, (s, p) => s + (p.precioBase * p.cantidad));
                    final total = listaConfirmacion.fold<num>(0, (s, p) => s + (p.precioFinal * p.cantidad));

                    if (widget.clienteId == null || _fechaEntrega == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe seleccionar un cliente y una fecha de entrega.')));
                      return;
                    }
                    // Obtener usuarioId desde PerfilUsuarioService
                    final perfilService = PerfilUsuarioService();
                    final userData = await perfilService.obtenerDatosUsuario();
                    final usuarioId = userData != null && userData['usua_Id'] != null
                        ? (userData['usua_Id'] is int ? userData['usua_Id'] : int.tryParse(userData['usua_Id'].toString()) ?? 0)
                        : 0;
                    if (usuarioId == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener el usuario actual.')));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PedidoConfirmarScreen(
                          productosSeleccionados: listaConfirmacion,
                          cantidadTotal: cantidadTotal,
                          subtotal: subtotal,
                          total: total,
                          clienteId: widget.clienteId,
                          fechaEntrega: _fechaEntrega!,
                          usuarioId: usuarioId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0C7A0), // Color dorado del proyecto
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
