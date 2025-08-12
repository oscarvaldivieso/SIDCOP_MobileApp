import 'package:flutter/material.dart';

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

  const PedidoConfirmarScreen({
    Key? key,
    required this.productosSeleccionados,
    required this.cantidadTotal,
    required this.subtotal,
    required this.total,
    required this.clienteId,
    required this.fechaEntrega,
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
                  // Aquí iría la lógica para confirmar el pedido y navegar a la factura
                  Navigator.pop(context, true);
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
