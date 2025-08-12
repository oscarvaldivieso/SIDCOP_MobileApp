import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
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
  final Map<int, int> _cantidades = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
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
                    'Precio: L. ${producto.prodPrecioUnitario}',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text('Selecciona fecha de entrega:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectFechaEntrega(context),
                  child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Selecciona productos y cantidades:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 6),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _productos.isEmpty
                      ? const Center(child: Text('No hay productos disponibles'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _productos.length,
                          itemBuilder: (context, idx) => _buildProductoItem(_productos[idx]),
                        ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
