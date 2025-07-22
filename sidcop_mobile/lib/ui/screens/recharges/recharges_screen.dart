import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart';
import 'package:sidcop_mobile/services/RecargasService.Dart';

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
                  // Filtrar recargas únicas por reca_Id
                  final Map<int, RecargasViewModel> unicas = {};
                  for (final r in recargas) {
                    if (r.reca_Id != null && !unicas.containsKey(r.reca_Id)) {
                      unicas[r.reca_Id!] = r;
                    }
                  }
                  final recargasUnicas = unicas.values.toList();
                  if (recargasUnicas.isEmpty) {
                    return const Center(child: Text('No hay recargas.'));
                  }
                  return Column(
                    children: recargasUnicas.map((recarga) {
                      return _buildHistorialCard(
                        _mapEstadoFromApi(recarga.reca_Confirmacion),
                        recarga.reca_Fecha != null ? _formatFechaFromApi(recarga.reca_Fecha!.toIso8601String()) : '-',
                        recarga.reDe_Cantidad != null
                            ? (recarga.reDe_Cantidad is int
                                ? recarga.reDe_Cantidad as int
                                : int.tryParse(recarga.reDe_Cantidad.toString()) ?? 0)
                            : 0,
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

  /// Helper para mapear el estado de la API a texto visual
  String _mapEstadoFromApi(dynamic recaConfirmacion) {
    // Cuando cambie a char, actualiza este método
    if (recaConfirmacion == true) return 'Aprobada';
    if (recaConfirmacion == false) return 'Rechazada';
    return 'En proceso';
  }

  /// Helper para formatear la fecha de la API
  String _formatFechaFromApi(String fechaIso) {
    try {
      final date = DateTime.parse(fechaIso);
      // Ejemplo: 21 de Julio del 2025
      return "${date.day} de "+_mesEnEspanol(date.month)+" del ${date.year}";
    } catch (_) {
      return fechaIso;
    }
  }

  String _mesEnEspanol(int mes) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes];
  }

  Widget _buildHistorialCard(String estado, String fecha, int cantidadProductos) {
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
  final List<Map<String, dynamic>> productos = [
    {
      'nombre': 'Café Espresso Americano Region Blend',
      'cantidad': 00,
      'img': 'assets/marca_blanco.png',
    },
  ];
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = productos
        .where((p) => p['nombre'].toLowerCase().contains(search.toLowerCase()))
        .toList();
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
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  return _buildProducto(filtered[i]);
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

  Widget _buildProducto(Map<String, dynamic> producto) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                producto['img'],
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                producto['nombre'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      producto['cantidad'] = (producto['cantidad'] as int) - 1;
                    });
                  },
                ),
                Text(
                  '${producto['cantidad']}',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() {
                      producto['cantidad'] = (producto['cantidad'] as int) + 1;
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
