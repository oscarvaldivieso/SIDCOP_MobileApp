import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final PedidosService _service = PedidosService();

  static const Color primaryColor = Color(0xFF141A2F); // Drawer principal
  static const Color goldColor = Color(0xFFE0C7A0); // Íconos y títulos

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Pedidos',
      icon: Icons.assignment,
      onRefresh: () async {
        setState(() {});
      },
      child: FutureBuilder<List<PedidosViewModel>>(
        future: _service.getPedidos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final pedidos = snapshot.data ?? [];
          if (pedidos.isEmpty) {
            return const Center(child: Text('No hay pedidos.'));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return _buildPedidoCard(pedido);
            },
          );
        },
      ),
    );
  }

  Widget _buildPedidoCard(PedidosViewModel pedido) {
  int cantidadProductos = 0;
  if (pedido.detallesJson != null && pedido.detallesJson!.isNotEmpty) {
    try {
      final List<dynamic> detalles = List.from(jsonDecode(pedido.detallesJson!));
      for (final item in detalles) {
        if (item is Map && item.containsKey('cantidad')) {
          final cant = item['cantidad'];
          if (cant is int) {
            cantidadProductos += cant;
          } else if (cant is String) {
            cantidadProductos += int.tryParse(cant) ?? 0;
          }
        }
      }
    } catch (_) {
      cantidadProductos = 0;
    }
  }
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    elevation: 4,
    color: primaryColor,
    child: Padding(
      padding: const EdgeInsets.all(18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment, color: goldColor, size: 32),
              ),
              const SizedBox(height: 6),
              Text(
                '$cantidadProductos producto${cantidadProductos == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido.clieNombreNegocio ?? 'Sin nombre de negocio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Satoshi',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cliente: ${pedido.clieNombres ?? ''} ${pedido.clieApellidos ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha pedido: ${_formatFecha(pedido.pediFechaPedido)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dirección: ${pedido.diClDireccionExacta ?? '-'}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: goldColor, size: 20),
        ],
      ),
    ),
  );
}

  String _formatFecha(DateTime fecha) {
    final meses = [
      '',
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return "${fecha.day} de ${meses[fecha.month]} del ${fecha.year}";
  }
}
