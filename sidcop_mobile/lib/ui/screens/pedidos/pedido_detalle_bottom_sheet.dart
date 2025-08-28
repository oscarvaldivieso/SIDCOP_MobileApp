import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/printer_service.dart';

class PedidoDetalleBottomSheet extends StatefulWidget {
  final PedidosViewModel pedido;
  const PedidoDetalleBottomSheet({super.key, required this.pedido});

  @override
  State<PedidoDetalleBottomSheet> createState() => _PedidoDetalleBottomSheetState();
}

class _PedidoDetalleBottomSheetState extends State<PedidoDetalleBottomSheet> {
  final PrinterService _printerService = PrinterService();
  bool _isPrinting = false;

  Color get _primaryColor => const Color(0xFF141A2F);
  Color get _goldColor => const Color(0xFFE0C7A0);
  Color get _surfaceColor => const Color(0xFFF8FAFC);
  Color get _borderColor => const Color(0xFFE2E8F0);

  Future<void> _printInvoice() async {
    if (!mounted) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      final selectedDevice = await _printerService.showPrinterSelectionDialog(context);
      if (selectedDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impresión cancelada'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final connected = await _printerService.connect(selectedDevice);
      if (!connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al conectar con la impresora'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final printSuccess = await _printerService.printPedido(widget.pedido); 

      await _printerService.disconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(printSuccess ? 'Pedido impreso exitosamente' : 'Error al imprimir el pedido'),
            backgroundColor: printSuccess ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
Widget build(BuildContext context) {
  final List<dynamic> detalles = _parseDetalles(widget.pedido.detallesJson);
  return DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    expand: false,
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFFE0C7A0), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Detalle del Pedido',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (_isPrinting)
                  const SizedBox(
                    width: 24, 
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5)
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: Colors.black54),
                    onPressed: _printInvoice,
                    tooltip: 'Imprimir Pedido',
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildInfoCard(
              icon: Icons.store,
              title: 'Negocio',
              value: widget.pedido.clieNombreNegocio ?? '-',
              color: _goldColor,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.event,
                    title: 'Pedido',
                    value: _formatFecha(widget.pedido.pediFechaPedido),
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.local_shipping,
                    title: 'Entrega',
                    value: _formatFecha(widget.pedido.pediFechaEntrega),
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Productos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            detalles.isEmpty
                ? const Text('No hay productos en este widget.pedido.')
                : Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: detalles.length,
                      separatorBuilder: (_, __) => const Divider(height: 22),
                      itemBuilder: (context, i) {
                        final item = detalles[i];
                        return _buildDetalleItem(item);
                      },
                    ),
                  ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _primaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _parseDetalles(String? detallesJson) {
    if (detallesJson == null || detallesJson.isEmpty) return [];
    try {
      return jsonDecode(detallesJson) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Widget _buildDetalleItem(dynamic item) {
    final String descripcion = item['descripcion']?.toString() ?? '';
    final String imagen = item['imagen']?.toString() ?? '';
    final int cantidad = item['cantidad'] is int
        ? item['cantidad']
        : int.tryParse(item['cantidad']?.toString() ?? '') ?? 0;
    final double precio = item['precio'] is double
        ? item['precio']
        : double.tryParse(item['precio']?.toString() ?? '') ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imagen.isNotEmpty
              ? Image.network(imagen, width: 60, height: 60, fit: BoxFit.cover)
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported_rounded, size: 32, color: Colors.grey),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descripcion,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text('Cantidad: $cantidad', style: const TextStyle(fontSize: 13)),
              Text('Precio: L. $precio', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '-';
    DateTime? f;
    if (fecha is DateTime) {
      f = fecha;
    } else if (fecha is String && fecha.isNotEmpty) {
      try {
        f = DateTime.parse(fecha);
      } catch (_) {}
    }
    if (f == null) return '-';
    final meses = [
      '',
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return "${f.day} de ${meses[f.month]} del ${f.year}";
  }
}
