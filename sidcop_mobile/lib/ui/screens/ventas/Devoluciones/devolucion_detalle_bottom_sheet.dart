import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';

class DevolucionDetalleBottomSheet extends StatefulWidget {
  final DevolucionesViewModel devolucion;

  const DevolucionDetalleBottomSheet({
    Key? key,
    required this.devolucion,
  }) : super(key: key);

  @override
  _DevolucionDetalleBottomSheetState createState() => _DevolucionDetalleBottomSheetState();
}

class _DevolucionDetalleBottomSheetState extends State<DevolucionDetalleBottomSheet> {
  late final DevolucionesService _devolucionesService;
  late Future<List<DevolucionDetalleModel>> _detallesFuture;

  @override
  void initState() {
    super.initState();
    _devolucionesService = DevolucionesService();
    _detallesFuture = _devolucionesService.getDevolucionDetalles(widget.devolucion.devoId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles de la Devolución',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF141A2F),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildModernDetailRow(
                    'Cliente',
                    widget.devolucion.clieNombreNegocio ?? 'N/A',
                    Icons.business,
                  ),
                  const Divider(height: 20, thickness: 1, indent: 40, endIndent: 10),
                  _buildModernDetailRow(
                    'Solicitada Por',
                    widget.devolucion.nombreCompleto ?? 'N/A',
                    Icons.person_outline,
                  ),
                  const Divider(height: 20, thickness: 1, indent: 40, endIndent: 10),
                  _buildModernDetailRow(
                    'Motivo',
                    widget.devolucion.devoMotivo,
                    Icons.receipt_long_outlined,
                  ),
                  const Divider(height: 20, thickness: 1, indent: 40, endIndent: 10),
                  _buildModernDetailRow(
                    'Fecha',
                    _formatDate(widget.devolucion.devoFecha),
                    Icons.calendar_today_outlined,
                  ),
                ],
              ),
            ),
            // Sección de productos
            const SizedBox(height: 20),
            Text(
              'Productos a devolver:',
              style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A2F),
                  ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<DevolucionDetalleModel>>(
              future: _detallesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No hay productos para esta devolución');
                }

                final detalles = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: detalles.length,
                  itemBuilder: (context, index) {
                    final detalle = detalles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          detalle.prod_Descripcion,
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Categoría: ${detalle.cate_Descripcion}',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          'Cantidad: 1', // Asumiendo 1 artículo por detalle de devolución
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: CustomButton(
                text: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                width: double.infinity,
                height: 56,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0C7A0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFE0C7A0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 15,
                    color: Color(0xFF141A2F),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    return '${_twoDigits(date?.day ?? 0)}/${_twoDigits(date?.month ?? 0)}/${date?.year ?? 0} ${_twoDigits(date?.hour ?? 0)}:${_twoDigits(date?.minute ?? 0)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

void showDevolucionDetalleBottomSheet({
  required BuildContext context,
  required DevolucionesViewModel devolucion,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DevolucionDetalleBottomSheet(devolucion: devolucion),
  );
}
