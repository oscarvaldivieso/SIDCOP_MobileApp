import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_screen.dart';

class ProductoConfirmacion {
  final String nombre;
  final int cantidad;
  final num precioBase;
  final num precioFinal;
  final String? imagen;

  ProductoConfirmacion({
    required this.nombre,
    required this.cantidad,
    required this.precioBase,
    required this.precioFinal,
    this.imagen,
  });
}

class PedidoConfirmarScreen extends StatelessWidget {
  final List<ProductoConfirmacion> productosSeleccionados;
  final int cantidadTotal;
  final num subtotal;
  final num total;
  final int clienteId;
  final DateTime fechaEntrega;
  final int usuarioId;

  const PedidoConfirmarScreen({
    Key? key,
    required this.productosSeleccionados,
    required this.cantidadTotal,
    required this.subtotal,
    required this.total,
    required this.clienteId,
    required this.fechaEntrega,
    required this.usuarioId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar Pedido')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente ID: $clienteId'),
            Text('Fecha de entrega: ${fechaEntrega.day.toString().padLeft(2, '0')}/${fechaEntrega.month.toString().padLeft(2, '0')}/${fechaEntrega.year}'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: productosSeleccionados.length,
                itemBuilder: (context, index) {
                  final p = productosSeleccionados[index];
                  return ListTile(
                    leading: p.imagen != null ? Image.network(p.imagen!) : null,
                    title: Text(p.nombre),
                    subtitle: Text('Cantidad: ${p.cantidad}  Unitario: ${p.precioFinal.toStringAsFixed(2)}'),
                    trailing: Text('Total: ${(p.precioFinal * p.cantidad).toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Cantidad total: $cantidadTotal'),
            Text('Subtotal: ${subtotal.toStringAsFixed(2)}'),
            Text('Total: ${total.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // Aquí navega a la factura tipo ticket pasando los datos
                  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => FacturaTicketScreen(
      clienteId: clienteId,
      usuarioId: usuarioId, // <-- Debe recibirse como argumento
      numeroFactura: 'F-0001',
      fechaFactura: DateTime.now(),
      fechaLimite: DateTime.now().add(const Duration(days: 30)), // Ejemplo: 30 días después
      productos: productosSeleccionados,
      subtotal: subtotal,
      totalDescuento: 0, // Ajustar si hay descuentos
      totalExento: 0, // TODO: calcular según productos
      totalExonerado: 0, // TODO: calcular según productos
      totalGravado15: 0, // TODO: calcular según productos
      totalGravado18: 0, // TODO: calcular según productos
      totalImpuesto15: 0, // TODO: calcular según productos
      totalImpuesto18: 0, // TODO: calcular según productos
      total: total,
    ),
  ),
);
                },
                child: const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
