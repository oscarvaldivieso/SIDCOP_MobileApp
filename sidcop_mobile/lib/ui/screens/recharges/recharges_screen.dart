import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart';
import 'package:sidcop_mobile/services/RecargasService.Dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';

class RechargesScreen extends StatefulWidget {
  const RechargesScreen({super.key});

  @override
  State<RechargesScreen> createState() => _RechargesScreenState();
}

class _RechargesScreenState extends State<RechargesScreen> {
  void _openRecargaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RecargaBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Recarga',
      icon: Icons.sync,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historial de solicitudes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Ver mas',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ],
              ),
              FutureBuilder<List<RecargasViewModel>>(
                future: RecargasService().getRecargas(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: \\${snapshot.error}'));
                  }
                  final recargas = snapshot.data ?? [];
                  final Map<int, List<RecargasViewModel>> agrupadas = {};
                  for (final r in recargas) {
                    if (r.reca_Id != null) {
                      agrupadas.putIfAbsent(r.reca_Id!, () => []).add(r);
                    }
                  }
                  if (agrupadas.isEmpty) {
                    return const Center(child: Text('No hay recargas.'));
                  }
                  return Column(
                    children: agrupadas.entries.take(3).map((entry) {
                      final recaId = entry.key;
                      final recargasGrupo = entry.value;
                      final recarga = recargasGrupo.first;
                      final totalCantidad = recargasGrupo.fold<int>(0, (
                        sum,
                        r,
                      ) {
                        if (r.reDe_Cantidad == null) return sum;
                        if (r.reDe_Cantidad is int)
                          return sum + (r.reDe_Cantidad as int);
                        return sum +
                            (int.tryParse(r.reDe_Cantidad.toString()) ?? 0);
                      });
                      return _buildHistorialCard(
                        _mapEstadoFromApi(recarga.reca_Confirmacion),
                        recarga.reca_Fecha != null
                            ? _formatFechaFromApi(
                                recarga.reca_Fecha!.toIso8601String(),
                              )
                            : '-',
                        totalCantidad,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Solicitar recarga',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _openRecargaModal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A2F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Abrir recarga',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mapEstadoFromApi(dynamic recaConfirmacion) {
    if (recaConfirmacion == "A") return 'Aprobada';
    if (recaConfirmacion == "R") return 'Rechazada';
    return 'En proceso';
  }

  String _formatFechaFromApi(String fechaIso) {
    try {
      final date = DateTime.parse(fechaIso);
      return "${date.day} de " +
          _mesEnEspanol(date.month) +
          " del ${date.year}";
    } catch (_) {
      return fechaIso;
    }
  }

  String _mesEnEspanol(int mes) {
    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[mes];
  }

  Widget _buildHistorialCard(
    String estado,
    String fecha,
    int cantidadProductos,
  ) {
    Color textColor;
    String label;
    switch (estado) {
      case 'En proceso':
      case 'Pendiente':
        label = 'En proceso';
        textColor = Colors.amber.shade700;
        break;
      case 'Aprobada':
        label = 'Aprobada';
        textColor = Colors.green.shade700;
        break;
      case 'Rechazada':
        label = 'Rechazada';
        textColor = Colors.red.shade700;
        break;
      default:
        label = estado;
        textColor = Colors.grey.shade700;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF181E34),
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fecha de solicitud: $fecha',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFF181E34),
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total productos solicitados: $cantidadProductos',
                style: const TextStyle(
                  color: Color(0xFF181E34),
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'Satoshi',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecargaBottomSheet extends StatefulWidget {
  const RecargaBottomSheet({super.key});

  @override
  State<RecargaBottomSheet> createState() => _RecargaBottomSheetState();
}

class _RecargaBottomSheetState extends State<RecargaBottomSheet> {
  final ProductosService _productosService = ProductosService();
  List<Productos> _productos = [];
  Map<int, int> _cantidades = {}; // prod_Id -> cantidad
  String search = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
  }

  Future<void> _fetchProductos() async {
    try {
      final productos = await _productosService.getProductos();
      setState(() {
        _productos = productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Solicitud de recarga',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar producto',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final producto = filtered[i];
                        final cantidad = _cantidades[producto.prod_Id] ?? 0;
                        return _buildProducto(producto, cantidad);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF141A2F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  'Solicitar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: producto.prod_Imagen != null && producto.prod_Imagen!.isNotEmpty
                  ? Image.network(
                      producto.prod_Imagen!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 48),
                    )
                  : const Icon(Icons.image, size: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                producto.prod_DescripcionCorta ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: cantidad > 0
                      ? () {
                          setState(() {
                            _cantidades[producto.prod_Id] = cantidad - 1;
                          });
                        }
                      : null,
                ),
                Text(
                  '$cantidad',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() {
                      _cantidades[producto.prod_Id] = cantidad + 1;
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
}
